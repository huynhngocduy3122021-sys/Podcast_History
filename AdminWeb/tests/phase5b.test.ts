import test from 'node:test'
import assert from 'node:assert/strict'
import axios from 'axios'
import { AxiosError } from 'axios'
import type { InternalAxiosRequestConfig } from 'axios'
import { QueryClient } from '@tanstack/react-query'
import { createAdminApi } from '../src/lib/admin-api.ts'
import { adminKeys, financeChangeConfirmed } from '../src/lib/admin-cache.ts'
import { approveWithdrawalSchema, completeWithdrawalSchema, walletSchema, withdrawalNoteSchema } from '../src/lib/admin-contracts.ts'
import { UnconfirmedMutationError } from '../src/lib/api-error.ts'
import { canAccess, sections } from '../src/lib/permissions.ts'
import { identityOf, sameIdentity } from '../src/lib/identity.ts'
import { pendingAction } from '../src/lib/pending-action.ts'

const withdrawalId = '11111111-1111-4111-8111-111111111111'
const walletId = '22222222-2222-4222-8222-222222222222'
const userId = '33333333-3333-4333-8333-333333333333'
const transactionId = '44444444-4444-4444-8444-444444444444'
const withdrawal = {
  withdrawalId, creatorId: userId, walletId, amount: '100000.00', currency: 'VND', payoutMethod: 'BANK_TRANSFER', payoutAccountMasked: '****1234',
  status: 'PENDING' as const, fundsReserved: false, payoutReference: null, note: null, requestedAt: '2026-10-14T10:00:00Z', processedAt: null,
}
const wallet = { walletId, userId, availableBalance: '250000.00', currency: 'VND', status: 'ACTIVE' }
const transaction = { transactionId, walletId, withdrawalId, paymentId: null, type: 'WITHDRAWAL', direction: 'OUT', amount: '100000.00', currency: 'VND', status: 'PENDING', referenceCode: `WITHDRAWAL:${withdrawalId}`, balanceAfter: '150000.00', createdAt: '2026-10-14T10:00:00Z' }
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

test('wallet and withdrawal APIs use the verified list/detail/history contracts', async () => {
  const approved = { ...withdrawal, status: 'PROCESSING' as const, fundsReserved: true }
  const rejected = { ...withdrawal, status: 'REJECTED' as const }
  const completed = { ...approved, status: 'COMPLETED' as const, fundsReserved: false, payoutReference: 'BANK-PAYOUT-001' }
  const failed = { ...approved, status: 'FAILED' as const, fundsReserved: false }
  const tx = transport([
    { data: page([wallet]) }, { data: page([transaction]) }, { data: page([withdrawal]) }, { data: withdrawal }, { data: page([{ reviewId: transactionId, reviewerId: userId, decision: 'APPROVED', note: 'Đã kiểm tra', reviewedAt: '2026-10-14T10:01:00Z' }]) },
    { data: approved }, { data: rejected }, { data: completed }, { data: failed },
  ])
  await tx.backend.wallets(1, 20)
  await tx.backend.walletTransactions({ walletId, status: 'PENDING', page: 0, size: 20 })
  await tx.backend.withdrawals({ status: 'PENDING', page: 0, size: 20 })
  await tx.backend.withdrawal(withdrawalId)
  await tx.backend.withdrawalReviews(withdrawalId, 0, 20)
  await tx.backend.approveWithdrawal(withdrawalId, { payoutAccountVerified: true, note: 'Đã kiểm tra tài khoản' })
  await tx.backend.rejectWithdrawal(withdrawalId, { note: 'Không thể xác minh' })
  await tx.backend.completeWithdrawal(withdrawalId, { payoutReference: ' BANK-PAYOUT-001 ', note: 'Đã chuyển khoản' })
  await tx.backend.failWithdrawal(withdrawalId, { note: 'Ngân hàng từ chối' })
  assert.equal(tx.calls[0].url, '/api/admin/wallets')
  assert.deepEqual(tx.calls[0].params, { page: 1, size: 20 })
  assert.deepEqual(tx.calls[1].params, { walletId, status: 'PENDING', page: 0, size: 20 })
  assert.deepEqual(tx.calls[2].params, { status: 'PENDING', page: 0, size: 20 })
  assert.equal(tx.calls[4].url, `/api/admin/withdrawals/${withdrawalId}/reviews`)
  assert.equal(tx.calls[5].url, `/api/admin/withdrawals/${withdrawalId}/approve`)
  assert.equal(tx.calls[6].url, `/api/admin/withdrawals/${withdrawalId}/reject`)
  assert.equal(tx.calls[7].url, `/api/admin/withdrawals/${withdrawalId}/complete`)
  assert.deepEqual(JSON.parse(String(tx.calls[7].data)), { payoutReference: 'BANK-PAYOUT-001', note: 'Đã chuyển khoản' })
  assert.equal(tx.calls[8].url, `/api/admin/withdrawals/${withdrawalId}/fail`)
})

test('wallet and withdrawal schemas expose only authoritative fields and enforce required notes', async () => {
  const parsedWallet = walletSchema.parse({ ...wallet, pendingBalance: '999999.00' })
  assert.equal(parsedWallet.availableBalance, '250000.00')
  assert.equal('pendingBalance' in parsedWallet, false)
  assert.equal(approveWithdrawalSchema.safeParse({ payoutAccountVerified: false, note: 'Đã kiểm tra' }).success, false)
  assert.equal(approveWithdrawalSchema.safeParse({ payoutAccountVerified: true, note: ' ' }).success, false)
  assert.equal(withdrawalNoteSchema.safeParse({ note: 'Từ chối vì thiếu xác minh' }).success, true)
  assert.equal(withdrawalNoteSchema.safeParse({ note: '' }).success, false)
  assert.equal(completeWithdrawalSchema.safeParse({ payoutReference: '', note: 'Đã chuyển' }).success, false)
  const invalid = transport([{ data: page([transaction]) }])
  await assert.rejects(invalid.backend.walletTransactions({ walletId: 'not-a-uuid', status: '', page: 0, size: 20 }))
  assert.equal(invalid.calls.length, 0)
})

test('withdrawal mutations require confirmed transitions and preserve business or uncertain outcomes', async () => {
  await assert.rejects(transport([{ data: withdrawal }]).backend.approveWithdrawal(withdrawalId, { payoutAccountVerified: true, note: 'Đã kiểm tra' }), UnconfirmedMutationError)
  const business = axios.create({ adapter: async config => {
    throw new AxiosError('business conflict', undefined, config, undefined, { data: { status: 409, error: 'Conflict', message: 'Request đã xử lý.', timestamp: new Date().toISOString() }, status: 409, statusText: 'Conflict', headers: {}, config })
  } })
  await assert.rejects(createAdminApi(business).completeWithdrawal(withdrawalId, { payoutReference: 'BANK-001', note: 'Đã chuyển' }), AxiosError)
  const uncertain = axios.create({ adapter: async config => {
    throw new AxiosError('gateway failure', 'ERR_BAD_RESPONSE', config, undefined, { data: {}, status: 503, statusText: 'Unavailable', headers: {}, config })
  } })
  await assert.rejects(createAdminApi(uncertain).failWithdrawal(withdrawalId, { note: 'Ngân hàng từ chối' }), UnconfirmedMutationError)
})

test('finance cache invalidation is scoped to the acting admin and related modules', async () => {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  client.setQueryData(adminKeys.withdrawalList(userId, 'PENDING', 0, 20), {})
  client.setQueryData(adminKeys.withdrawalDetail(userId, withdrawalId), withdrawal)
  client.setQueryData(adminKeys.withdrawalReviews(userId, withdrawalId, 0, 20), {})
  client.setQueryData(adminKeys.walletList(userId, 0, 20), page([wallet]))
  client.setQueryData(adminKeys.walletTransactions(userId, walletId, 'PENDING', 0, 20), page([transaction]))
  client.setQueryData(['dashboard', userId, 'ADMIN'], {})
  client.setQueryData(adminKeys.walletList('other-user', 0, 20), {})
  await financeChangeConfirmed(client, userId, { ...withdrawal, status: 'PROCESSING', fundsReserved: true })
  assert.equal(client.getQueryState(adminKeys.withdrawalList(userId, 'PENDING', 0, 20))?.isInvalidated, true)
  assert.equal(client.getQueryState(adminKeys.withdrawalDetail(userId, withdrawalId))?.isInvalidated, true)
  assert.equal(client.getQueryState(adminKeys.withdrawalReviews(userId, withdrawalId, 0, 20))?.isInvalidated, true)
  assert.equal(client.getQueryState(adminKeys.walletList(userId, 0, 20))?.isInvalidated, true)
  assert.equal(client.getQueryState(adminKeys.walletTransactions(userId, walletId, 'PENDING', 0, 20))?.isInvalidated, true)
  assert.equal(client.getQueryState(['dashboard', userId, 'ADMIN'])?.isInvalidated, true)
  assert.equal(client.getQueryState(adminKeys.walletList('other-user', 0, 20))?.isInvalidated, false)
  client.clear()
})

test('wallets and withdrawals are ADMIN-only and duplicate actions are locked', async () => {
  assert.equal(canAccess('ADMIN', true), true)
  assert.equal(canAccess('STAFF', true), false)
  assert.equal(sections.find(section => section.path === '/wallets')?.adminOnly, true)
  assert.equal(sections.find(section => section.path === '/withdrawals')?.adminOnly, true)
  const admin = identityOf({ id: userId, role: 'ADMIN' })
  assert.equal(sameIdentity(admin, identityOf({ id: userId, role: 'STAFF' })), false)
  const run = pendingAction()
  let release!: () => void
  let calls = 0
  const first = run(async () => { calls++; await new Promise<void>(resolve => { release = resolve }) })
  assert.equal(await run(async () => { calls++ }), false)
  assert.equal(calls, 1)
  release()
  await first
})
