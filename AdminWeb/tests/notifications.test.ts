import test from 'node:test'
import assert from 'node:assert/strict'
import axios, { AxiosError } from 'axios'
import { QueryClient } from '@tanstack/react-query'
import { countUnreadNotifications, createNotificationApi, markNotificationReadInCache, notificationKeys } from '../src/lib/notifications.ts'
import { notificationsPageSchema } from '../src/lib/contracts.ts'
import type { NotificationsPage } from '../src/lib/contracts.ts'
import { UnconfirmedMutationError } from '../src/lib/api-error.ts'

const notificationId = '11111111-1111-4111-8111-111111111111'
const actorId = '22222222-2222-4222-8222-222222222222'
const otherId = '33333333-3333-4333-8333-333333333333'
const item = { notificationId, type: 'REPORT_RESULT', title: 'Kết quả báo cáo', message: '<b>Không được thực thi</b>', read: false, createdAt: '2026-10-14T08:00:00Z', readAt: null }
const page = { content: [item], number: 0, size: 20, totalElements: 1, totalPages: 1 }

function transport(responses: Array<{ data?: unknown; status?: number }>) {
  const calls: Array<{ url?: string; method?: string; params?: unknown; data?: unknown }> = []
  const client = axios.create({ adapter: async config => {
    calls.push({ url: config.url, method: config.method, params: config.params, data: config.data })
    const next = responses.shift() || { data: page, status: 200 }
    return { data: next.data, status: next.status ?? 200, statusText: 'OK', headers: {}, config }
  } })
  return { backend: createNotificationApi(client), calls }
}

test('personal notification API uses paginated REST endpoints and confirmed 204 read contract', async () => {
  const tx = transport([{ data: page }, { status: 204, data: undefined }])
  const result = await tx.backend.list(2, 20)
  await tx.backend.markRead(notificationId)
  assert.deepEqual(result.content, [item])
  assert.equal(tx.calls[0].url, '/api/me/notifications')
  assert.deepEqual(tx.calls[0].params, { page: 2, size: 20 })
  assert.equal(tx.calls[1].url, `/api/me/notifications/${notificationId}/read`)
  assert.equal(tx.calls[1].method, 'put')
})

test('known notification read failures remain visible and uncertain 204 outcomes are not confirmed', async () => {
  const known = axios.create({ adapter: async config => {
    const response = { data: { message: 'business failure' }, status: 403, statusText: 'Forbidden', headers: {}, config }
    throw new AxiosError('request failed', undefined, config, undefined, response)
  } })
  await assert.rejects(createNotificationApi(known).markRead(notificationId), error => axios.isAxiosError(error) && error.response?.status === 403)
  const uncertain = transport([{ status: 500, data: {} }])
  await assert.rejects(uncertain.backend.markRead(notificationId), UnconfirmedMutationError)
})

test('notification cache updates read state only for the matching personal item', () => {
  const parsed = notificationsPageSchema.parse(page)
  const updated = markNotificationReadInCache(parsed, notificationId)
  assert.equal(updated?.content[0].read, true)
  assert.equal(updated?.content[0].readAt !== null, true)
  assert.equal(markNotificationReadInCache(parsed, otherId)?.content[0].read, false)
  const client = new QueryClient()
  client.setQueryData(notificationKeys.page(actorId, 0, 20), parsed)
  client.setQueryData(notificationKeys.page(otherId, 0, 20), parsed)
  client.setQueryData(notificationKeys.page(actorId, 1, 20), parsed)
  assert.equal(client.getQueryData<NotificationsPage>(notificationKeys.page(otherId, 0, 20))?.content[0].read, false)
  client.clear()
})

test('unread notification count is derived from the authenticated page and becomes zero after read cache update', () => {
  const parsed = notificationsPageSchema.parse(page)
  assert.equal(countUnreadNotifications(parsed), 1)
  assert.equal(countUnreadNotifications(markNotificationReadInCache(parsed, notificationId)), 0)
  assert.equal(countUnreadNotifications(undefined), 0)
})
