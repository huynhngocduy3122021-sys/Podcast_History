import test from 'node:test'
import assert from 'node:assert/strict'
import axios from 'axios'
import { AxiosError, AxiosHeaders } from 'axios'
import type { InternalAxiosRequestConfig } from 'axios'
import { QueryClient } from '@tanstack/react-query'
import { createAdminApi } from '../src/lib/admin-api.ts'
import { adminKeys, planChangeConfirmed, staffChangeConfirmed, userChangeConfirmed } from '../src/lib/admin-cache.ts'
import { planWriteSchema, staffCreateSchema, userProfileSchema, uuidFilterSchema } from '../src/lib/admin-contracts.ts'
import { canAccess } from '../src/lib/permissions.ts'
import { UnconfirmedMutationError } from '../src/lib/api-error.ts'
import { identityOf, sameIdentity } from '../src/lib/identity.ts'

const userId = '11111111-1111-4111-8111-111111111111'
const planId = '22222222-2222-4222-8222-222222222222'
const creatorId = '33333333-3333-4333-8333-333333333333'
const actorId = '44444444-4444-4444-8444-444444444444'
const user = { userId, username: 'listener', email: 'listener@example.com', displayName: 'Listener', avatarUrl: null, bio: null, role: 'LISTENER' as const, active: true, verified: false, createdAt: '2026-10-13T10:00:00Z', lastLoginAt: null }
const plan = { planId, creatorId, name: 'Gói tháng', description: null, price: '50000.00', currency: 'VND', durationDays: 30, status: 'ACTIVE' as const }
const audit = { auditId: planId, actorId, action: 'UPDATE_PLAN', resourceType: 'MEMBERSHIP_PLAN', resourceId: planId, note: 'Đã cập nhật', createdAt: '2026-10-13T10:00:00Z' }

function transport(responses: Array<{ data: unknown; status?: number }>) {
  const calls: InternalAxiosRequestConfig[] = []
  const http = axios.create({ adapter: async config => {
    calls.push(config)
    const next = responses.shift() || { data: {}, status: 200 }
    return { data: next.data, status: next.status || 200, statusText: 'OK', headers: {}, config }
  } })
  return { backend: createAdminApi(http), calls }
}

const page = <T>(content: T[]) => ({ content, number: 0, size: 20, totalElements: content.length, totalPages: content.length ? 1 : 0 })

test('user management maps exact admin endpoints, filters, bodies and confirmed state', async () => {
  const tx = transport([
    { data: page([user]) }, { data: user }, { data: user },
    { data: { ...user, active: false } }, { data: { ...user, verified: true } },
    { data: { ...user, role: 'STAFF' } }, { data: user },
  ])
  await tx.backend.users({ q: 'listener', role: 'LISTENER', active: true, page: 0, size: 20 })
  await tx.backend.user(userId)
  await tx.backend.updateUser(userId, { displayName: ' New name ', avatarUrl: '', bio: '' })
  await tx.backend.changeAccess(userId, { active: false, note: 'Khóa theo yêu cầu' })
  await tx.backend.changeVerification(userId, { verified: true, note: 'Đã kiểm tra' })
  await tx.backend.changeRole(userId, { role: 'STAFF', note: 'Phân công' })
  await tx.backend.revokeSessions(userId, { note: 'Thu hồi' })
  assert.equal(tx.calls[0].url, '/api/admin/users')
  assert.deepEqual(tx.calls[0].params, { q: 'listener', role: 'LISTENER', active: true, page: 0, size: 20 })
  assert.equal(tx.calls[2].method, 'patch')
  assert.deepEqual(JSON.parse(String(tx.calls[2].data)), { displayName: 'New name', avatarUrl: '', bio: '' })
  assert.equal(tx.calls[3].url, `/api/admin/users/${userId}/access`)
  assert.equal(tx.calls[5].url, `/api/admin/users/${userId}/role`)
  assert.equal(tx.calls[6].url, `/api/admin/users/${userId}/revoke-sessions`)
  assert.equal(canAccess('STAFF', true), false)
  await assert.rejects(tx.backend.changeAccess(userId, { active: false, note: ' ' }))
})

test('staff creation enforces DTO limits, uses 201 and never parses a password field', async () => {
  const values = { username: 'new-staff', email: 'staff@example.com', password: 'secure-pass', displayName: 'Nhân viên mới' }
  assert.equal(staffCreateSchema.safeParse({ ...values, username: 'ab' }).success, false)
  assert.equal(staffCreateSchema.safeParse({ ...values, password: 'x'.repeat(73) }).success, false)
  const tx = transport([{ data: { ...user, role: 'STAFF' }, status: 201 }])
  const result = await tx.backend.createStaff(values)
  assert.equal(result.role, 'STAFF')
  assert.equal('password' in result, false)
  assert.equal(tx.calls[0].method, 'post')
  assert.deepEqual(JSON.parse(String(tx.calls[0].data)), values)
})

test('membership plans preserve decimal text and implement CRUD/status contract', async () => {
  const values = { creatorId, name: 'Gói tháng', description: '', price: '50000.01', currency: 'VND', durationDays: 30, status: 'ACTIVE' as const }
  assert.equal(planWriteSchema.parse(values).price, '50000.01')
  assert.equal(planWriteSchema.safeParse({ ...values, price: '0.001' }).success, false)
  const tx = transport([
    { data: page([plan]) }, { data: plan }, { data: { ...plan, price: '50000.01' }, status: 201 },
    { data: { ...plan, price: '50000.01' } }, { data: { ...plan, status: 'INACTIVE' } },
  ])
  await tx.backend.plans({ creatorId, status: 'ACTIVE', page: 0, size: 20 })
  await tx.backend.plan(planId)
  await tx.backend.savePlan(undefined, values)
  await tx.backend.savePlan(planId, values)
  await tx.backend.deactivatePlan(planId, { note: 'Không còn bán' })
  assert.equal(tx.calls[0].url, '/api/admin/membership-plans')
  assert.equal(tx.calls[0].params.creatorId, creatorId)
  assert.equal('status' in tx.calls[0].params, false)
  assert.equal(tx.calls[2].method, 'post')
  assert.equal(tx.calls[3].method, 'put')
  assert.equal(tx.calls[4].method, 'delete')
  assert.deepEqual(JSON.parse(String(tx.calls[4].data)), { note: 'Không còn bán' })
  const malformed = transport([{ data: { ...plan, status: 'ACTIVE' }, status: 204 }])
  await assert.rejects(malformed.backend.deactivatePlan(planId, { note: 'Tắt' }), UnconfirmedMutationError)
})

test('audit logs are paginated, filterable and read-only', async () => {
  const tx = transport([{ data: page([audit]) }])
  const result = await tx.backend.auditLogs({ resourceType: 'USER', resourceId: userId, page: 1, size: 20 })
  assert.equal(result.content[0].action, 'UPDATE_PLAN')
  assert.deepEqual(tx.calls[0].params, { resourceType: 'USER', resourceId: userId, page: 1, size: 20 })
  assert.equal('put' in tx.backend, false)
})

test('Phase 4 cache invalidation stays scoped to the current admin identity', async () => {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  queryClient.setQueryData(adminKeys.userList(actorId, '', '', '', 0, 20), {})
  queryClient.setQueryData(adminKeys.staff(actorId, 0, 20), {})
  queryClient.setQueryData(adminKeys.planList(actorId, '', '', 0, 20), {})
  queryClient.setQueryData(['dashboard', actorId, 'ADMIN'], {})
  queryClient.setQueryData(['dashboard', userId, 'ADMIN'], {})
  queryClient.setQueryData(adminKeys.userList(userId, '', '', '', 0, 20), {})
  await userChangeConfirmed(queryClient, actorId, userId)
  await staffChangeConfirmed(queryClient, actorId)
  await planChangeConfirmed(queryClient, actorId, planId)
  assert.equal(queryClient.getQueryState(adminKeys.userList(actorId, '', '', '', 0, 20))?.isInvalidated, true)
  assert.equal(queryClient.getQueryState(adminKeys.staff(actorId, 0, 20))?.isInvalidated, true)
  assert.equal(queryClient.getQueryState(adminKeys.planList(actorId, '', '', 0, 20))?.isInvalidated, true)
  assert.equal(queryClient.getQueryState(['dashboard', actorId, 'ADMIN'])?.isInvalidated, true)
  assert.equal(queryClient.getQueryState(['dashboard', userId, 'ADMIN'])?.isInvalidated, false)
  assert.equal(queryClient.getQueryState(adminKeys.userList(userId, '', '', '', 0, 20))?.isInvalidated, false)
  queryClient.clear()
})

test('user profile contract uses Java UTF-16 limits', () => {
  assert.equal(userProfileSchema.safeParse({ displayName: 'x'.repeat(120), avatarUrl: '', bio: '' }).success, true)
  assert.equal(userProfileSchema.safeParse({ displayName: 'x'.repeat(121), avatarUrl: '', bio: '' }).success, false)
  assert.equal(userProfileSchema.safeParse({ displayName: '😀'.repeat(61), avatarUrl: '', bio: '' }).success, false)
})

test('UUID filters reject empty fragments and malformed values before transport', async () => {
  assert.equal(uuidFilterSchema.safeParse('').success, true)
  assert.equal(uuidFilterSchema.safeParse('33333333-3333-4333-8333-33333333333').success, false)
  assert.equal(uuidFilterSchema.safeParse('not-a-uuid').success, false)
  assert.equal(uuidFilterSchema.safeParse(creatorId).success, true)

  const invalidPlans = transport([{ data: page([plan]) }])
  await assert.rejects(invalidPlans.backend.plans({ creatorId: '33333333-', page: 0, size: 20 }))
  assert.equal(invalidPlans.calls.length, 0)
  const invalidAudits = transport([{ data: page([audit]) }])
  await assert.rejects(invalidAudits.backend.auditLogs({ resourceId: '4444', page: 0, size: 20 }))
  assert.equal(invalidAudits.calls.length, 0)

  const valid = transport([{ data: page([plan]) }, { data: page([audit]) }])
  await valid.backend.plans({ creatorId, page: 0, size: 20 })
  await valid.backend.auditLogs({ resourceId: actorId, page: 0, size: 20 })
  assert.equal(valid.calls[0].params.creatorId, creatorId)
  assert.equal(valid.calls[1].params.resourceId, actorId)
})

test('pending mutations require the same authenticated identity and role', () => {
  const admin = identityOf({ id: actorId, role: 'ADMIN' })
  assert.equal(sameIdentity(admin, identityOf({ id: actorId, role: 'ADMIN' })), true)
  assert.equal(sameIdentity(admin, identityOf({ id: userId, role: 'ADMIN' })), false)
  assert.equal(sameIdentity(admin, identityOf({ id: actorId, role: 'STAFF' })), false)
  assert.equal(sameIdentity(admin, null), false)
})

test('sensitive admin mutations preserve 401, 403, 404 and 409 responses', async () => {
  for (const status of [401, 403, 404, 409]) {
    const http = axios.create({ adapter: async config => {
      const response = { status, data: { status, error: 'Error', message: `business ${status}`, timestamp: new Date().toISOString() }, statusText: 'Error', headers: {}, config }
      throw new AxiosError('request failed', undefined, { ...config, headers: new AxiosHeaders(config.headers) }, undefined, response)
    } })
    const backend = createAdminApi(http)
    await assert.rejects(
      backend.changeAccess(userId, { active: false, note: 'Kiểm tra lỗi' }),
      error => error instanceof AxiosError && error.response?.status === status,
    )
  }
})
