import test from 'node:test'
import assert from 'node:assert/strict'
import axios from 'axios'
import type { InternalAxiosRequestConfig } from 'axios'
import { createAdminApi } from '../../src/lib/admin-api.ts'

const withdrawalId = '11111111-1111-4111-8111-111111111111'
const creatorId = '22222222-2222-4222-8222-222222222222'
const milestoneId = '33333333-3333-4333-8333-333333333333'

test('mocked E2E: admin payout and milestone evidence workflows traverse the API boundary', async () => {
  const pending = { withdrawalRequestId: withdrawalId, creatorProfileId: creatorId, amount: '100.00', currency: 'VND', payoutMethod: 'BANK', payoutAccountMasked: '****', payoutAccountReference: null, status: 'PENDING', requestedAt: '2026-10-31T08:00:00Z', note: null }
  const dispute = { disputeId: withdrawalId, milestoneId, raisedByUserId: creatorId, reason: 'reason', status: 'OPEN', decision: null, resolutionNote: null, reviewedByUserId: null, createdAt: '2026-10-31T08:00:00Z', resolvedAt: null, responseDeadlineAt: null, opponentConfirmedAt: null, listenerWinAction: null }
  const calls: InternalAxiosRequestConfig[] = []
  const http = axios.create({ adapter: async config => {
    calls.push(config)
    if (calls.length === 1) return { data: [pending], status: 200, statusText: 'OK', headers: {}, config }
    if (calls.length === 2) return { data: { ...pending, status: 'FAILED' }, status: 200, statusText: 'OK', headers: {}, config }
    if (calls.length === 3) return { data: [dispute], status: 200, statusText: 'OK', headers: {}, config }
    if (calls.length === 4) return { data: [], status: 200, statusText: 'OK', headers: {}, config }
    return { data: { ...dispute, status: 'RESOLVED', decision: 'LISTENER_WINS' }, status: 200, statusText: 'OK', headers: {}, config }
  } })
  const backend = createAdminApi(http)
  await backend.pendingPayouts()
  await backend.recordPayoutResult(withdrawalId, { result: 'FAILED', note: 'isolated test provider failure' })
  await backend.milestoneDisputes('OPEN')
  await backend.milestoneDisputeSubmissions(milestoneId)
  await backend.resolveMilestoneDispute(withdrawalId, { decision: 'LISTENER_WINS', note: 'isolated test decision' })
  assert.deepEqual(calls.map(call => call.url), [
    '/api/admin/payouts/withdrawals/pending',
    `/api/admin/payouts/withdrawals/${withdrawalId}/result`,
    '/api/admin/milestone-disputes',
    `/api/milestones/${milestoneId}/submissions`,
    `/api/admin/milestone-disputes/${withdrawalId}/resolve`,
  ])
})
