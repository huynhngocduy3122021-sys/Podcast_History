// Opt-in smoke check: real login creates a session; finally always attempts logout.
// No tokens, credentials or personal response data are printed or written to disk.
import { readFileSync } from 'node:fs'
import { tokenSchema, meSchema, dashboardSchema } from '../src/lib/contracts.ts'
import { apiHeaders } from '../src/lib/api-config.ts'

const env = readFileSync(new URL('../.env', import.meta.url), 'utf8')
const line = env.match(/^\s*VITE_API_BASE_URL\s*=\s*(.+)$/m)?.[1]
if (!line) throw new Error('Missing VITE_API_BASE_URL in AdminWeb/.env')
const base = line.trim().replace(/^['"]|['"]$/g, '').replace(/\/$/, '')
const headers = apiHeaders(base)
let failures = 0
async function request(method, path, body, accessToken, expected = 200, extraHeaders = {}) {
  const response = await fetch(`${base}${path}`, {
    method, signal: AbortSignal.timeout(20000),
    headers: { ...headers, ...extraHeaders, ...(body ? { 'Content-Type': 'application/json' } : {}), ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
  })
  console.log(`${method} ${path}: HTTP ${response.status}${response.status === expected ? ' OK' : ` (expected ${expected})`}`)
  if (response.status !== expected) { failures++; return { ok: false, response } }
  return { ok: true, response }
}
const health = await request('GET', '/api/health')
if (!health.ok) process.exit(1)
if ((await health.response.json()).status !== 'UP') throw new Error('Unexpected health response')
const cors = await request('OPTIONS', '/api/auth/login', undefined, undefined, 200, {
  Origin: 'http://localhost:5173',
  'Access-Control-Request-Method': 'POST',
  'Access-Control-Request-Headers': 'content-type,ngrok-skip-browser-warning',
})
console.log(`CORS allowed origin: ${cors.response.headers.get('access-control-allow-origin') || '(missing)'}`)
if (cors.response.headers.get('access-control-allow-origin') !== 'http://localhost:5173') failures++

const credentials = readFileSync(new URL('../../docs/TEST_ACCOUNTS.md', import.meta.url), 'utf8')
for (const [role, name] of [['ADMIN', 'ph_admin'], ['STAFF', 'ph_staff01']]) {
  const row = credentials.split(/\r?\n/).find(row => row.includes(`\`${name}\``))
  if (!row) throw new Error(`Missing documented ${role} account`)
  const columns = row.split('|').map(cell => cell.trim().replaceAll('`', ''))
  console.log(`\nChecking ${role}`)
  let pair
  try {
    const login = await request('POST', '/api/auth/login', { identifier: columns[2], password: columns[4] })
    if (!login.ok) continue
    const raw = await login.response.json()
    pair = raw // Retain refresh token for cleanup even if the schema fails.
    pair = tokenSchema.parse(raw)
    if (pair.user.role !== role) throw new Error(`Unexpected ${role} account role`)
    const me = await request('GET', '/api/auth/me', undefined, pair.accessToken)
    if (me.ok && meSchema.parse(await me.response.json()).role !== role) throw new Error('Unexpected /me role')
    const prefix = '/api/admin'
    const dashboard = await request('GET', `${prefix}/dashboard`, undefined, pair.accessToken)
    if (dashboard.ok) dashboardSchema.parse(await dashboard.response.json())
    for (const path of ['/podcasts/page?size=1', '/reports?size=1', '/podcast-appeals?size=1']) {
      await request('GET', `${prefix}${path}`, undefined, pair.accessToken)
    }
    await request('GET', '/api/me/notifications?size=1', undefined, pair.accessToken)
    if (role === 'STAFF') await request('GET', '/api/admin/users?size=1', undefined, pair.accessToken, 403)
    const refreshed = await request('POST', '/api/auth/refresh', { refreshToken: pair.refreshToken })
    if (refreshed.ok) {
      const rotated = await refreshed.response.json()
      const previous = pair.refreshToken
      pair = rotated
      pair = tokenSchema.parse(rotated)
      if (previous === pair.refreshToken) throw new Error('Refresh token did not rotate')
      console.log('Refresh token rotation: OK')
      const renewed = await request('GET', '/api/auth/me', undefined, pair.accessToken)
      if (renewed.ok && meSchema.parse(await renewed.response.json()).role !== role) throw new Error('Unexpected refreshed role')
    }
  } catch (error) {
    failures++
    // Schema errors can contain data, so do not dump their objects or stack.
    console.log(`Verification failed: ${error.name || 'Error'}`)
  } finally {
    if (pair?.refreshToken) await request('POST', '/api/auth/logout', { refreshToken: pair.refreshToken }, undefined, 204)
  }
}
console.log(`\nSmoke check failures: ${failures}`)
process.exitCode = failures ? 1 : 0
