import test from 'node:test'
import assert from 'node:assert/strict'
import axios from 'axios'
import { AxiosError } from 'axios'
import type { InternalAxiosRequestConfig } from 'axios'
import { QueryClient } from '@tanstack/react-query'
import { createAdminApi } from '../src/lib/admin-api.ts'
import { adminKeys, disputeChangeConfirmed } from '../src/lib/admin-cache.ts'
import { contractSchema, disputeSchema, openDisputeSchema, resolveDisputeSchema } from '../src/lib/admin-contracts.ts'
import { UnconfirmedMutationError } from '../src/lib/api-error.ts'
import { canAccess, sections } from '../src/lib/permissions.ts'

const contractId = '11111111-1111-4111-8111-111111111111'
const disputeId = '22222222-2222-4222-8222-222222222222'
const listenerId = '33333333-3333-4333-8333-333333333333'
const creatorId = '44444444-4444-4444-8444-444444444444'
const stageId = '55555555-5555-4555-8555-555555555555'
const page = <T>(content: T[]) => ({ content, number: 0, size: 20, totalElements: content.length, totalPages: content.length ? 1 : 0 })
const contract = { contractId, listenerId, creatorId, status: 'DISPUTED', createdAt: '2026-10-14T10:00:00Z', stages: [{ stageId, name: 'Chặng 1', order: 1, status: 'APPROVED' }] }
const dispute = { disputeId, contractId, openedById: listenerId, reason: 'Cần rà soát', previousContractStatus: 'ACTIVE', status: 'OPEN', decision: null, note: null, reviewerId: null, createdAt: '2026-10-14T10:01:00Z', resolvedAt: null }

function transport(responses: Array<{ data: unknown; status?: number }>) {
  const calls: InternalAxiosRequestConfig[] = []
  const http = axios.create({ adapter: async config => {
    calls.push(config)
    const next = responses.shift() || { data: {}, status: 200 }
    return { data: next.data, status: next.status || 200, statusText: 'OK', headers: {}, config }
  } })
  return { backend: createAdminApi(http), calls }
}

test('contracts and disputes APIs follow verified list/detail/open/resolve contracts', async () => {
  const resolved = { ...dispute, status: 'RESOLVED', decision: 'RESUME_CONTRACT', note: 'Đã rà soát' }
  const tx = transport([{ data: page([contract]) }, { data: contract }, { data: dispute, status: 201 }, { data: page([dispute]) }, { data: dispute }, { data: resolved }])
  await tx.backend.contracts({ status: 'DISPUTED', page: 0, size: 20 })
  await tx.backend.contract(contractId)
  await tx.backend.openDispute(contractId, { note: 'Cần rà soát' })
  await tx.backend.disputes({ status: 'OPEN', page: 0, size: 20 })
  await tx.backend.dispute(disputeId)
  await tx.backend.resolveDispute(disputeId, { decision: 'RESUME_CONTRACT', note: 'Đã rà soát' })
  assert.equal(tx.calls[0].url, '/api/admin/contracts')
  assert.deepEqual(tx.calls[0].params, { status: 'DISPUTED', page: 0, size: 20 })
  assert.equal(tx.calls[1].url, `/api/admin/contracts/${contractId}`)
  assert.equal(tx.calls[2].url, `/api/admin/contracts/${contractId}/disputes`)
  assert.deepEqual(JSON.parse(String(tx.calls[2].data)), { note: 'Cần rà soát' })
  assert.equal(tx.calls[3].url, '/api/admin/disputes')
  assert.equal(tx.calls[4].url, `/api/admin/disputes/${disputeId}`)
  assert.equal(tx.calls[5].url, `/api/admin/disputes/${disputeId}/resolve`)
  assert.deepEqual(JSON.parse(String(tx.calls[5].data)), { decision: 'RESUME_CONTRACT', note: 'Đã rà soát' })
})

test('contract and dispute schemas enforce authoritative fields and required notes', () => {
  assert.equal(contractSchema.parse({ ...contract, ignored: 'not exposed' }).stages[0].status, 'APPROVED')
  assert.equal(disputeSchema.parse({ ...dispute, ignored: 'not exposed' }).decision, null)
  assert.equal('ignored' in contractSchema.parse({ ...contract, ignored: 'not exposed' }), false)
  assert.equal(openDisputeSchema.safeParse({ note: ' ' }).success, false)
  assert.equal(resolveDisputeSchema.safeParse({ decision: 'NO_SUCH_DECISION', note: 'x' }).success, false)
  assert.equal(resolveDisputeSchema.safeParse({ decision: 'CANCEL_CONTRACT', note: 'Đã đối soát' }).success, true)
})

test('contract and dispute mutations never report success without matching authoritative transition', async () => {
  await assert.rejects(transport([{ data: dispute }]).backend.openDispute(contractId, { note: 'Cần rà soát' }), UnconfirmedMutationError)
  await assert.rejects(transport([{ data: dispute }]).backend.resolveDispute(disputeId, { decision: 'RESUME_CONTRACT', note: 'Đã rà soát' }), UnconfirmedMutationError)
  const business = axios.create({ adapter: async config => {
    throw new AxiosError('business conflict', undefined, config, undefined, { data: { status: 409, error: 'Conflict', message: 'Chưa đủ điều kiện.', timestamp: new Date().toISOString() }, status: 409, statusText: 'Conflict', headers: {}, config })
  } })
  await assert.rejects(createAdminApi(business).resolveDispute(disputeId, { decision: 'COMPLETE_CONTRACT', note: 'Đã kiểm tra' }), AxiosError)
})

test('dispute cache invalidation stays scoped to the acting admin and related resources', async () => {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  client.setQueryData(adminKeys.disputeList(listenerId, 'OPEN', 0, 20), page([dispute]))
  client.setQueryData(adminKeys.disputeDetail(listenerId, disputeId), dispute)
  client.setQueryData(adminKeys.contractList(listenerId, 'DISPUTED', 0, 20), page([contract]))
  client.setQueryData(adminKeys.contractDetail(listenerId, contractId), contract)
  client.setQueryData(['dashboard', listenerId], {})
  client.setQueryData(adminKeys.disputeList(creatorId, 'OPEN', 0, 20), {})
  await disputeChangeConfirmed(client, listenerId, { ...dispute, status: 'RESOLVED', decision: 'RESUME_CONTRACT', note: 'Đã rà soát' })
  assert.equal(client.getQueryState(adminKeys.disputeList(listenerId, 'OPEN', 0, 20))?.isInvalidated, true)
  assert.equal(client.getQueryState(adminKeys.disputeDetail(listenerId, disputeId))?.isInvalidated, true)
  assert.equal(client.getQueryState(adminKeys.contractList(listenerId, 'DISPUTED', 0, 20))?.isInvalidated, true)
  assert.equal(client.getQueryState(adminKeys.contractDetail(listenerId, contractId))?.isInvalidated, true)
  assert.equal(client.getQueryState(adminKeys.disputeList(creatorId, 'OPEN', 0, 20))?.isInvalidated, false)
})

test('contracts and disputes remain ADMIN-only', () => {
  assert.equal(canAccess('ADMIN', true), true)
  assert.equal(canAccess('STAFF', true), false)
  assert.equal(sections.find(section => section.path === '/contracts')?.adminOnly, true)
  assert.equal(sections.find(section => section.path === '/disputes')?.adminOnly, true)
})
