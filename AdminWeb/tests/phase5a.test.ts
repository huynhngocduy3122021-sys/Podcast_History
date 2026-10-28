import test from 'node:test'
import assert from 'node:assert/strict'
import axios from 'axios'
import { AxiosError } from 'axios'
import type { InternalAxiosRequestConfig } from 'axios'
import { QueryClient } from '@tanstack/react-query'
import { createAdminApi } from '../src/lib/admin-api.ts'
import { adminKeys, paymentChangeConfirmed } from '../src/lib/admin-cache.ts'
import { paymentReconcileSchema, paymentRefundSchema } from '../src/lib/admin-contracts.ts'
import { UnconfirmedMutationError } from '../src/lib/api-error.ts'
import { canAccess, sections } from '../src/lib/permissions.ts'
import { identityOf, sameIdentity } from '../src/lib/identity.ts'

const paymentId = '11111111-1111-4111-8111-111111111111'
const userId = '22222222-2222-4222-8222-222222222222'
const payment = {
  paymentId, userId, subscriptionId: null, requestId: null, stageId: null, amount: '50000.00', currency: 'VND', status: 'PENDING' as const,
  provider: null, providerTransactionId: null, createdAt: '2026-10-14T10:00:00Z', paidAt: null, refundReference: null, refundedAt: null,
}
const page = <T>(content: T[]) => ({ content, number: 0, size: 20, totalElements: content.length, totalPages: content.length ? 1 : 0 })

function transport(responses: Array<{ data: unknown; status?: number }>) {
  const calls: InternalAxiosRequestConfig[] = []
  const http = axios.create({ adapter: async config => {
    calls.push(config)
    const next = responses.shift() || { data: {}, status: 200 }
    return { data: next.data, status: next.status || 200, statusText: 'OK', headers: {}, config }
  } })
  return { backend: createAdminApi(http), calls }
}

test('payments use the verified list/detail/reconcile/refund contract and zero-based pagination', async () => {
  const tx = transport([
    { data: page([payment]) }, { data: payment },
    { data: { ...payment, status: 'PAID', providerTransactionId: 'BANK-001' } },
    { data: { ...payment, status: 'REFUNDED', refundReference: 'REFUND-001' } },
  ])
  await tx.backend.payments({ status: 'PENDING', page: 2, size: 20 })
  await tx.backend.payment(paymentId)
  await tx.backend.reconcilePayment(paymentId, { result: 'PAID', providerTransactionId: ' BANK-001 ', note: 'Đã đối chiếu' })
  await tx.backend.refundPayment(paymentId, { refundReference: ' REFUND-001 ', note: 'Đã chuyển trả' })
  assert.equal(tx.calls[0].url, '/api/admin/payments')
  assert.deepEqual(tx.calls[0].params, { status: 'PENDING', page: 2, size: 20 })
  assert.equal(tx.calls[1].url, `/api/admin/payments/${paymentId}`)
  assert.equal(tx.calls[2].url, `/api/admin/payments/${paymentId}/reconcile`)
  assert.deepEqual(JSON.parse(String(tx.calls[2].data)), { result: 'PAID', providerTransactionId: 'BANK-001', note: 'Đã đối chiếu' })
  assert.equal(tx.calls[3].url, `/api/admin/payments/${paymentId}/refund`)
  assert.deepEqual(JSON.parse(String(tx.calls[3].data)), { refundReference: 'REFUND-001', note: 'Đã chuyển trả' })
})

test('financial request validation follows Backend required fields and states', async () => {
  assert.equal(paymentReconcileSchema.safeParse({ result: 'PAID', providerTransactionId: '', note: 'Đối soát' }).success, false)
  assert.equal(paymentReconcileSchema.safeParse({ result: 'FAILED', note: 'Không nhận được tiền' }).success, true)
  assert.equal(paymentRefundSchema.safeParse({ refundReference: 'REFUND-001', note: 'Đã chuyển trả' }).success, true)
  assert.equal(paymentRefundSchema.safeParse({ refundReference: '', note: 'Đã chuyển trả' }).success, false)
  const invalid = transport([{ data: page([payment]) }])
  await assert.rejects(invalid.backend.payments({ status: 'NOT_A_STATUS' as never, page: 0, size: 20 }))
  assert.equal(invalid.calls.length, 0)
})

test('financial mutations require Backend-confirmed terminal state and preserve business errors', async () => {
  await assert.rejects(transport([{ data: payment }]).backend.reconcilePayment(paymentId, { result: 'PAID', providerTransactionId: 'BANK-001', note: 'Đã đối soát' }), UnconfirmedMutationError)
  const business = axios.create({ adapter: async config => {
    throw new AxiosError('business conflict', undefined, config, undefined, { data: { status: 409, error: 'Conflict', message: 'Payment đã được xử lý.', timestamp: new Date().toISOString() }, status: 409, statusText: 'Conflict', headers: {}, config })
  } })
  await assert.rejects(createAdminApi(business).refundPayment(paymentId, { refundReference: 'REFUND-001', note: 'Đã chuyển trả' }), AxiosError)
  const http = axios.create({ adapter: async config => {
    throw new AxiosError('gateway failure', 'ERR_BAD_RESPONSE', config, undefined, { data: {}, status: 503, statusText: 'Unavailable', headers: {}, config })
  } })
  await assert.rejects(createAdminApi(http).reconcilePayment(paymentId, { result: 'FAILED', note: 'Không nhận được tiền' }), UnconfirmedMutationError)
})

test('payment cache invalidation stays scoped to the acting admin identity', async () => {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  client.setQueryData(adminKeys.paymentList(userId, 'PENDING', 0, 20), {})
  client.setQueryData(adminKeys.paymentDetail(userId, paymentId), payment)
  client.setQueryData(['dashboard', userId, 'ADMIN'], {})
  client.setQueryData(adminKeys.paymentList('other-user', 'PENDING', 0, 20), {})
  await paymentChangeConfirmed(client, userId, { ...payment, status: 'PAID', providerTransactionId: 'BANK-001' })
  assert.equal(client.getQueryState(adminKeys.paymentList(userId, 'PENDING', 0, 20))?.isInvalidated, true)
  assert.equal(client.getQueryState(adminKeys.paymentDetail(userId, paymentId))?.isInvalidated, true)
  assert.equal(client.getQueryState(['dashboard', userId, 'ADMIN'])?.isInvalidated, true)
  assert.equal(client.getQueryState(adminKeys.paymentList('other-user', 'PENDING', 0, 20))?.isInvalidated, false)
  client.clear()
})

test('payments are ADMIN-only and identity changes invalidate mutation ownership', () => {
  assert.equal(canAccess('ADMIN', true), true)
  assert.equal(canAccess('STAFF', true), false)
  assert.equal(sections.find(section => section.path === '/payments')?.adminOnly, true)
  const admin = identityOf({ id: userId, role: 'ADMIN' })
  assert.equal(sameIdentity(admin, identityOf({ id: userId, role: 'STAFF' })), false)
  assert.equal(sameIdentity(admin, identityOf({ id: 'other-user', role: 'ADMIN' })), false)
})
