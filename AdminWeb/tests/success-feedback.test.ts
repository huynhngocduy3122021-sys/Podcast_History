import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import axios, { AxiosError } from 'axios'
import { MutationObserver, QueryClient } from '@tanstack/react-query'
import { createAdminApi } from '../src/lib/admin-api.ts'
import { categorySaveSuccess, successMessages } from '../src/lib/success-feedback.ts'
import { creatorReviewConfirmed, categoryChangeConfirmed, adminKeys } from '../src/lib/admin-cache.ts'

const id = '11111111-1111-4111-8111-111111111111'
const applicantId = '22222222-2222-4222-8222-222222222222'
const application = { applicationId: id, applicantUserId: applicantId, username: 'test', email: 'test@example.invalid', channelName: null, introduction: null, portfolioUrl: null, status: 'PENDING', reviewNote: null, submittedAt: null, reviewedAt: null }
const category = { categoryId: id, name: 'Lịch sử', slug: 'lich-su', description: null, active: true, createdAt: null, updatedAt: null }
const values = { name: category.name, slug: category.slug, description: '', active: true }
const queryClient = () => new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })
const backend = (data: unknown, status = 200) => createAdminApi(axios.create({ adapter: async config => ({ data, status, statusText: '', config, headers: {} }) }))

test('approved Vietnamese messages remain exact and logout keeps its existing wording', () => {
  assert.deepEqual(successMessages, {
    creatorApproved: 'Đã duyệt hồ sơ Creator thành công.',
    creatorRejected: 'Đã từ chối hồ sơ Creator.',
    categoryCreated: 'Tạo danh mục thành công.',
    categoryUpdated: 'Cập nhật danh mục thành công.',
    categoryDeactivated: 'Đã ngừng hoạt động danh mục.',
    categoryReactivated: 'Đã kích hoạt lại danh mục.',
    logout: 'Đã đăng xuất.',
  })
  // Logout already uses the approved wording; protect it without rewriting the UI.
  assert.ok(readFileSync('src/components/layout.tsx', 'utf8').includes("notify('Đã đăng xuất.')"))
})

test('creator mutations only emit the action-specific message after verified status and cache updates', async () => {
  for (const [decision, status, message] of [
    ['approve', 'APPROVED', 'Đã duyệt hồ sơ Creator thành công.'],
    ['reject', 'REJECTED', 'Đã từ chối hồ sơ Creator.'],
  ] as const) {
    const client = queryClient()
    client.setQueryData(['dashboard', applicantId, 'ADMIN'], { pendingCreators: 1 })
    const feedback: string[] = []
    const api = backend({ ...application, status })
    const mutation = new MutationObserver(client, {
      mutationFn: () => api.review(id, decision, { note: decision === 'reject' ? 'Cần bổ sung hồ sơ' : '' }),
      onSuccess: async data => {
        await creatorReviewConfirmed(client, applicantId, data)
        feedback.push(decision === 'approve' ? successMessages.creatorApproved : successMessages.creatorRejected)
      },
    })
    await mutation.mutate()
    assert.deepEqual(feedback, [message])
    assert.equal(client.getQueryState(['dashboard', applicantId, 'ADMIN'])?.isInvalidated, true)
    assert.equal(client.getQueryData<{ status: string }>(adminKeys.creatorDetail(applicantId, id))?.status, status)
    client.clear()
  }
})

test('category messages distinguish create, update, deactivate and reactivate after confirmation', async () => {
  for (const scenario of [
    { before: undefined, after: true, message: 'Tạo danh mục thành công.' },
    { before: true, after: true, message: 'Cập nhật danh mục thành công.' },
    { before: false, after: false, message: 'Cập nhật danh mục thành công.' },
    { before: true, after: false, message: 'Đã ngừng hoạt động danh mục.' },
    { before: false, after: true, message: 'Đã kích hoạt lại danh mục.' },
  ]) {
    const client = queryClient()
    const key = adminKeys.categories(applicantId)
    client.setQueryData(key, [category])
    const feedback: string[] = []
    const previous = scenario.before === undefined ? undefined : { ...category, active: scenario.before }
    const api = backend({ ...category, active: scenario.after }, previous ? 200 : 201)
    const mutation = new MutationObserver(client, {
      mutationFn: () => api.saveCategory(previous?.categoryId, { ...values, active: scenario.after }),
      onSuccess: async data => {
        await categoryChangeConfirmed(client, applicantId)
        feedback.push(categorySaveSuccess(previous, data))
      },
    })
    await mutation.mutate()
    assert.deepEqual(feedback, [scenario.message])
    assert.equal(client.getQueryState(key)?.isInvalidated, true)
    client.clear()
  }
  const confirmed = await backend({ ...category, active: false }).deactivateCategory(id)
  assert.equal(confirmed.active, false)
  assert.equal(successMessages.categoryDeactivated, 'Đã ngừng hoạt động danh mục.')
})

test('malformed or contradictory mutation responses never trigger success feedback', async () => {
  const client = queryClient()
  const feedback: string[] = []
  for (const api of [backend({}), backend(application), backend({ ...application, status: 'APPROVED', applicationId: applicantId })]) {
    const mutation = new MutationObserver(client, {
      mutationFn: () => api.review(id, 'approve', { note: '' }),
      onSuccess: () => { feedback.push(successMessages.creatorApproved) },
    })
    await assert.rejects(mutation.mutate())
    assert.equal(mutation.getCurrentResult().status, 'error')
  }
  for (const api of [backend(category, 200), backend({ ...category, active: false }, 201)]) {
    const mutation = new MutationObserver(client, {
      mutationFn: () => api.saveCategory(undefined, values),
      onSuccess: () => { feedback.push(successMessages.categoryCreated) },
    })
    await assert.rejects(mutation.mutate())
  }
  assert.deepEqual(feedback, [])
  client.clear()
})

test('known business errors and lost mutation responses never trigger success feedback', async () => {
  const client = queryClient()
  const feedback: string[] = []
  for (const status of [undefined, 400, 403, 404, 409, 503]) {
    const api = createAdminApi(axios.create({ adapter: async config => {
      throw new AxiosError('mock error', undefined, config, undefined, status === undefined ? undefined : {
        status, data: { timestamp: new Date().toISOString(), status, error: 'Error', message: 'business error' }, headers: {}, statusText: '', config,
      })
    } }))
    const mutation = new MutationObserver(client, {
      mutationFn: () => api.saveCategory(undefined, values),
      onSuccess: () => { feedback.push(successMessages.categoryCreated) },
    })
    await assert.rejects(mutation.mutate())
  }
  assert.deepEqual(feedback, [])
  client.clear()
})
