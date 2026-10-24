import test from 'node:test'
import assert from 'node:assert/strict'
import axios, { AxiosError } from 'axios'
import type { InternalAxiosRequestConfig } from 'axios'
import { QueryClient, MutationObserver } from '@tanstack/react-query'
import { createAdminApi } from '../src/lib/admin-api.ts'
import { adminKeys, creatorReviewConfirmed, categoryChangeConfirmed } from '../src/lib/admin-cache.ts'
import { pendingAction } from '../src/lib/pending-action.ts'
import { UnconfirmedMutationError, extractApiError } from '../src/lib/api-error.ts'

const profileId = '11111111-1111-4111-8111-111111111111'
const userId = '22222222-2222-4222-8222-222222222222'
const application = { applicationId: profileId, applicantUserId: userId, username: 'test', email: 'test@example.com', channelName: null, introduction: null, portfolioUrl: null, status: 'PENDING' as const, reviewNote: null, submittedAt: null, reviewedAt: null }
const category = { categoryId: profileId, name: 'Test', slug: 'test', description: null, active: false, createdAt: null, updatedAt: null }
const values = { name: 'Test', slug: 'test', description: '', active: true }

function transport(data: unknown, status = 200) {
  const calls: InternalAxiosRequestConfig[] = []
  const http = axios.create({ adapter: async config => {
    calls.push(config)
    return { data, status, statusText: 'OK', headers: {}, config }
  } })
  return { backend: createAdminApi(http), calls }
}

test('creator list/detail use admin endpoints, zero-based params and profile ID, not applicant ID', async () => {
  const list = transport({ content: [application], number: 2, size: 20, totalElements: 41, totalPages: 3 })
  const signal = new AbortController().signal
  assert.equal((await list.backend.applications('PENDING', 2, 20, signal)).number, 2)
  assert.equal(list.calls[0].url, '/api/admin/creator-applications')
  assert.deepEqual(list.calls[0].params, { status: 'PENDING', page: 2, size: 20 })
  assert.equal(list.calls[0].signal, signal)
  await list.backend.applications('', 0, 20)
  assert.equal(list.calls[1].params.status, undefined)
  const detail = transport(application)
  const parsed = await detail.backend.application(profileId)
  assert.equal(detail.calls[0].url, `/api/admin/creator-applications/${profileId}`)
  assert.notEqual(parsed.applicationId, parsed.applicantUserId)
})

test('review validates before HTTP, sends note and checks backend-confirmed result', async () => {
  const rejected = transport({ ...application, status: 'REJECTED', reviewNote: 'Need more detail' })
  await assert.rejects(rejected.backend.review(profileId, 'reject', { note: '   ' }))
  assert.equal(rejected.calls.length, 0)
  const result = await rejected.backend.review(profileId, 'reject', { note: ' Need more detail ' })
  assert.equal(result.status, 'REJECTED')
  assert.equal(rejected.calls[0].method, 'post')
  assert.equal(rejected.calls[0].url, `/api/admin/creator-applications/${profileId}/reject`)
  assert.deepEqual(JSON.parse(rejected.calls[0].data), { note: 'Need more detail' })
  const approved = transport({ ...application, status: 'APPROVED' })
  await approved.backend.review(profileId, 'approve', { note: '' })
  assert.equal(approved.calls[0].url, `/api/admin/creator-applications/${profileId}/approve`)
  await assert.rejects(transport(application).backend.review(profileId, 'approve', { note: '' }), UnconfirmedMutationError)
  await assert.rejects(transport({ ...application, status: 'APPROVED', applicationId: userId }).backend.review(profileId, 'approve', { note: '' }), UnconfirmedMutationError)
})

test('categories accept a direct List with inactive records, create/update and DELETE deactivation', async () => {
  const list = transport([category])
  assert.equal((await list.backend.categories())[0].active, false)
  assert.equal(list.calls[0].url, '/api/admin/categories')
  assert.equal(list.calls[0].params, undefined)
  await assert.rejects(transport({ content: [category] }).backend.categories())
  const create = transport({ ...category, active: true }, 201)
  await create.backend.saveCategory(undefined, values)
  const edit = transport({ ...category, active: true })
  await edit.backend.saveCategory(profileId, values)
  const deactivate = transport(category)
  await deactivate.backend.deactivateCategory(profileId)
  assert.deepEqual([create.calls[0].method, edit.calls[0].method, deactivate.calls[0].method], ['post', 'put', 'delete'])
  assert.equal(edit.calls[0].url, `/api/admin/categories/${profileId}`)
  assert.deepEqual(JSON.parse(edit.calls[0].data), values)
  assert.equal(deactivate.calls[0].data, undefined)
  await assert.rejects(transport({ ...category, active: true }).backend.deactivateCategory(profileId), UnconfirmedMutationError)
})

test('category mutations reject mismatched identity, state, name, status or malformed DTO', async () => {
  for (const data of [{ ...category, categoryId: userId, active: true }, category, { ...category, name: 'Another', active: true }, {}]) {
    await assert.rejects(transport(data).backend.saveCategory(profileId, values), UnconfirmedMutationError)
  }
  await assert.rejects(transport({ ...category, active: true }, 200).backend.saveCategory(undefined, values), UnconfirmedMutationError)
  await assert.rejects(transport(category, 204).backend.deactivateCategory(profileId), UnconfirmedMutationError)
  await assert.rejects(transport({ ...category, categoryId: userId }).backend.deactivateCategory(profileId), UnconfirmedMutationError)
  await assert.rejects(transport({ ...application, status: 'APPROVED' }, 201).backend.review(profileId, 'approve', { note: '' }), UnconfirmedMutationError)
})

test('uncertain mutation results are distinguished from confirmed business errors without automatic retry', async () => {
  for (const status of [undefined, 400, 403, 404, 409, 500, 502, 503]) {
    let calls = 0
    let original!: AxiosError
    const backend = createAdminApi(axios.create({ adapter: async config => {
      calls++
      original = new AxiosError('request failed', 'ECONNABORTED', config, undefined, status === undefined ? undefined : {
        data: { timestamp: new Date().toISOString(), status, error: 'Error', message: 'Tên category đã được sử dụng.' },
        status, statusText: '', headers: {}, config,
      })
      throw original
    } }))
    await assert.rejects(backend.saveCategory(undefined, values), error => {
      if (status === undefined || status >= 500) assert.equal(extractApiError(error).outcomeUnknown, true)
      else assert.equal(error, original)
      return true
    })
    assert.equal(calls, 1)
  }
})

test('successful creator mutation invalidates list and dashboard, updates detail, isolates other identities', async () => {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })
  const listKey = adminKeys.creatorList(userId, 'PENDING', 0, 20)
  client.setQueryData(listKey, { content: [application] })
  client.setQueryData(['dashboard', userId, 'ADMIN'], { pendingCreators: 1 })
  client.setQueryData(['dashboard', 'another-user', 'ADMIN'], { pendingCreators: 2 })
  client.setQueryData(adminKeys.categories(userId), [category])
  const confirmed = { ...application, status: 'APPROVED' as const }
  const mutation = new MutationObserver(client, { mutationFn: async () => confirmed, onSuccess: data => creatorReviewConfirmed(client, userId, data) })
  await mutation.mutate()
  assert.equal(client.getQueryState(listKey)?.isInvalidated, true)
  assert.equal(client.getQueryState(['dashboard', userId, 'ADMIN'])?.isInvalidated, true)
  assert.equal(client.getQueryState(['dashboard', 'another-user', 'ADMIN'])?.isInvalidated, false)
  assert.deepEqual(client.getQueryData(adminKeys.creatorDetail(userId, profileId)), confirmed)
  assert.equal(client.getQueryState(adminKeys.categories(userId))?.isInvalidated, false)
  await categoryChangeConfirmed(client, userId)
  assert.equal(client.getQueryState(adminKeys.categories(userId))?.isInvalidated, true)
  client.clear()
})

test('failed mutation never signals success or updates caches and can be retried', async () => {
  const client = new QueryClient({ defaultOptions: { mutations: { retry: false } } })
  const key = adminKeys.creatorList(userId, 'PENDING', 0, 20)
  client.setQueryData(key, { content: [application] })
  let successes = 0
  let attempts = 0
  const mutation = new MutationObserver(client, {
    mutationFn: async () => { attempts++; throw new AxiosError('conflict') },
    onSuccess: async data => { successes++; await creatorReviewConfirmed(client, userId, data) },
  })
  await assert.rejects(mutation.mutate())
  assert.equal(mutation.getCurrentResult().status, 'error')
  assert.equal(successes, 0)
  assert.equal(attempts, 1)
  assert.equal(client.getQueryState(key)?.isInvalidated, false)
  assert.equal(client.getQueryData(adminKeys.creatorDetail(userId, profileId)), undefined)
  client.clear()
})

test('confirmation lock prevents repeated submissions while pending and unlocks after failure', async () => {
  const run = pendingAction()
  let release!: () => void
  let calls = 0
  const first = run(async () => { calls++; await new Promise<void>(resolve => { release = resolve }) })
  assert.equal(await run(async () => { calls++ }), false)
  assert.equal(calls, 1)
  release()
  assert.equal(await first, true)
  await assert.rejects(run(async () => { throw new Error('409') }), /409/)
  assert.equal(await run(async () => { calls++ }), true)
  assert.equal(calls, 2)
})
