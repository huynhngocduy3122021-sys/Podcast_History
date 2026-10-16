// Default: read-only workflows and non-existent-ID validation checks.
// --category-mutations creates ONE unique fixture, then edits/deactivates it.
// Never approves/rejects an existing Creator profile without explicit fixture IDs.
import { readFileSync } from 'node:fs'
import { randomUUID } from 'node:crypto'
import { tokenSchema } from '../src/lib/contracts.ts'
import { creatorApplicationsPageSchema, creatorApplicationSchema, categoriesSchema, categorySchema } from '../src/lib/admin-contracts.ts'
import { apiHeaders } from '../src/lib/api-config.ts'

const env = readFileSync(new URL('../.env', import.meta.url), 'utf8')
const rawBase = env.match(/^\s*VITE_API_BASE_URL\s*=\s*(.+)$/m)?.[1]
if (!rawBase) throw new Error('Missing VITE_API_BASE_URL')
const base = rawBase.trim().replace(/^['"]|['"]$/g, '').replace(/\/$/, '')
const credentials = readFileSync(new URL('../../docs/DEV_ACCOUNTS.md', import.meta.url), 'utf8')
const headers = apiHeaders(base)
let failures = 0

async function request(method, path, token, body, expected = 200) {
  const response = await fetch(`${base}${path}`, {
    method, signal: AbortSignal.timeout(20000),
    headers: { ...headers, ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(body === undefined ? {} : { 'Content-Type': 'application/json' }) },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  })
  console.log(`${method} ${path.replace(/[0-9a-f]{8}-[0-9a-f-]{27}/gi, '{id}')}: HTTP ${response.status} (expected ${expected})`)
  if (response.status !== expected) throw new Error('Unexpected HTTP status')
  if (response.status === 204) return undefined
  const text = await response.text()
  // Spring Security can return an empty 403; controller DTOs still require JSON.
  if (!text.trim()) return undefined
  return JSON.parse(text)
}

async function categoryWorkflow(token) {
  const suffix = randomUUID()
  const values = { name: `Phase2 QA ${suffix}`, slug: `phase2-qa-${suffix}`, description: 'Isolated Phase 2 API test fixture', active: true }
  let fixture
  try {
    fixture = await request('POST', '/api/admin/categories', token, values, 201)
    const created = categorySchema.parse(fixture)
    if (!created.active) throw new Error('Category creation not confirmed')
    await request('POST', '/api/admin/categories', token, values, 409)
    await request('POST', '/api/admin/categories', token, { ...values, name: `${values.name} duplicate slug` }, 409)
    const updated = categorySchema.parse(await request('PUT', `/api/admin/categories/${created.categoryId}`, token, { ...values, description: 'Updated test fixture', active: false }))
    if (updated.active || updated.description !== 'Updated test fixture') throw new Error('Category update not confirmed')
    const all = categoriesSchema.parse(await request('GET', '/api/admin/categories', token))
    if (!all.some(item => item.categoryId === created.categoryId && !item.active)) throw new Error('Inactive category missing from list')
    // Explicitly verify reactivation through PUT before testing DELETE.
    const active = categorySchema.parse(await request('PUT', `/api/admin/categories/${created.categoryId}`, token, values))
    if (!active.active) throw new Error('Category reactivation not confirmed')
  } finally {
    if (fixture?.categoryId) {
      try {
        const inactive = categorySchema.parse(await request('DELETE', `/api/admin/categories/${fixture.categoryId}`, token))
        if (inactive.active) { failures++; console.log('Fixture deactivation not confirmed') }
        else console.log('Category fixture cleanup: inactive (soft deletion; record retained by Backend)')
      } catch { failures++; console.log('Fixture cleanup failed; inspect test categories before rerunning') }
    }
  }
}

for (const [role, username] of [['ADMIN', 'ph_admin'], ['STAFF', 'ph_staff01']]) {
  let tokens
  try {
    const row = credentials.split(/\r?\n/).find(line => line.includes(`\`${username}\``))
    if (!row) throw new Error('Missing documented dev account')
    const columns = row.split('|').map(cell => cell.trim().replaceAll('`', ''))
    tokens = await request('POST', '/api/auth/login', undefined, { identifier: columns[2], password: columns[4] })
    tokenSchema.parse(tokens)
    if (tokens.user.role !== role) throw new Error('Unexpected dev account role')
    console.log(`Checking Phase 2 permissions: ${role}`)
    const missingId = randomUUID()
    if (role === 'STAFF') {
      await request('GET', '/api/admin/categories', tokens.accessToken, undefined, 403)
      await request('GET', '/api/admin/creator-applications?page=0&size=2', tokens.accessToken, undefined, 403)
      await request('POST', `/api/admin/creator-applications/${missingId}/reject`, tokens.accessToken, { note: 'Permission check' }, 403)
      continue
    }
    categoriesSchema.parse(await request('GET', '/api/admin/categories', tokens.accessToken))
    for (const status of ['', 'PENDING', 'APPROVED', 'REJECTED']) {
      const page = creatorApplicationsPageSchema.parse(await request('GET', `/api/admin/creator-applications?page=0&size=2${status ? `&status=${status}` : ''}`, tokens.accessToken))
      if (page.content[0]) {
        const first = page.content[0]
        const detail = creatorApplicationSchema.parse(await request('GET', `/api/admin/creator-applications/${first.applicationId}`, tokens.accessToken))
        if (detail.applicationId !== first.applicationId || detail.applicantUserId !== first.applicantUserId) throw new Error('Detail ID mapping mismatch')
      }
    }
    await request('GET', `/api/admin/creator-applications/${missingId}`, tokens.accessToken, undefined, 404)
    await request('POST', `/api/admin/creator-applications/${missingId}/reject`, tokens.accessToken, { note: ' ' }, 400)
    await request('POST', `/api/admin/creator-applications/${missingId}/reject`, tokens.accessToken, { note: 'x'.repeat(2001) }, 400)
    await request('POST', `/api/admin/creator-applications/${missingId}/approve`, tokens.accessToken, { note: '' }, 404)
    await request('POST', '/api/admin/categories', tokens.accessToken, { name: ' ', slug: 'valid', description: '', active: true }, 400)
    await request('POST', '/api/admin/categories', tokens.accessToken, { name: 'Invalid slug QA', slug: '---', description: '', active: true }, 400)
    await request('PUT', `/api/admin/categories/${missingId}`, tokens.accessToken, { name: 'Missing QA', slug: 'missing', description: '', active: true }, 404)
    if (process.argv.includes('--category-mutations')) await categoryWorkflow(tokens.accessToken)
  } catch (error) {
    failures++
    console.log(`Phase 2 verification failed: ${error.name || 'Error'} (details and response data suppressed)`)
  } finally {
    if (tokens?.refreshToken) {
      try { await request('POST', '/api/auth/logout', undefined, { refreshToken: tokens.refreshToken }, 204) }
      catch { failures++; console.log('Could not confirm test session logout') }
    }
  }
}
console.log(`Phase 2 smoke check failures: ${failures}`)
process.exitCode = failures ? 1 : 0
