import test from 'node:test'
import assert from 'node:assert/strict'
import axios from 'axios'
import type { InternalAxiosRequestConfig } from 'axios'
import { createAdminApi } from '../src/lib/admin-api.ts'
import { UnconfirmedMutationError } from '../src/lib/api-error.ts'
import { payoutAccountWriteSchema, payoutResultWriteSchema } from '../src/lib/admin-contracts.ts'

const withdrawalId = '11111111-1111-4111-8111-111111111111'
const creatorId = '22222222-2222-4222-8222-222222222222'
const milestoneId = '33333333-3333-4333-8333-333333333333'
const disputeId = '44444444-4444-4444-8444-444444444444'
const submissionId = '55555555-5555-4555-8555-555555555555'

const pending = {
  withdrawalRequestId: withdrawalId,
  creatorProfileId: creatorId,
  amount: '125000.00',
  currency: 'VND',
  payoutMethod: 'BANK',
  payoutAccountMasked: '****1234',
  payoutAccountReference: 'bank-ref',
  status: 'PENDING',
  requestedAt: '2026-10-31T08:00:00Z',
  note: null,
}

function transport(responses: Array<{ data: unknown; status?: number }>) {
  const calls: InternalAxiosRequestConfig[] = []
  const http = axios.create({ adapter: async config => {
    calls.push(config)
    const next = responses.shift() || { data: {}, status: 200 }
    return { data: next.data, status: next.status || 200, statusText: 'OK', headers: {}, config }
  } })
  return { backend: createAdminApi(http), calls }
}

test('payout API uses pending/result/account contracts and enforces SUCCESS reference', async () => {
  const completed = { ...pending, status: 'COMPLETED' }
  const account = { payoutAccountId: withdrawalId, creatorProfileId: creatorId, payoutMethod: 'BANK', accountMasked: '****1234', currency: 'VND', verified: true, active: true }
  const tx = transport([{ data: [pending] }, { data: completed }, { data: account, status: 201 }])
  const list = await tx.backend.pendingPayouts()
  await tx.backend.recordPayoutResult(withdrawalId, { result: 'SUCCESS', providerReference: 'provider-123', note: 'paid' })
  await tx.backend.registerPayoutAccount(creatorId, { payoutMethod: 'BANK', accountReference: 'bank-ref', accountMasked: '****1234', currency: 'VND' })
  assert.equal(list[0].status, 'PENDING')
  assert.equal(tx.calls[0].url, '/api/admin/payouts/withdrawals/pending')
  assert.deepEqual(JSON.parse(String(tx.calls[1].data)), { result: 'SUCCESS', providerReference: 'provider-123', note: 'paid' })
  assert.equal(tx.calls[2].url, `/api/admin/payouts/creators/${creatorId}/accounts`)
  assert.equal(payoutResultWriteSchema.safeParse({ result: 'SUCCESS' }).success, false)
  assert.equal(payoutAccountWriteSchema.safeParse({ payoutMethod: 'BANK', accountReference: 'ref', accountMasked: '****', currency: 'VN' }).success, false)
})

test('payout result never reports success for the wrong authoritative status', async () => {
  await assert.rejects(
    transport([{ data: pending }]).backend.recordPayoutResult(withdrawalId, { result: 'FAILED', note: 'provider rejected' }),
    UnconfirmedMutationError,
  )
})

test('milestone dispute flow loads evidence through signed media URLs and resolves supported decisions', async () => {
  const dispute = {
    disputeId, milestoneId, raisedByUserId: creatorId, reason: 'needs review', status: 'OPEN', decision: null,
    resolutionNote: null, reviewedByUserId: null, createdAt: '2026-10-31T08:00:00Z', resolvedAt: null,
    responseDeadlineAt: '2026-11-01T08:00:00Z', opponentConfirmedAt: null, listenerWinAction: null,
  }
  const submission = { submissionId, milestoneId, revisionNumber: 1, objectKey: 'private/key', publicUrl: null, contentType: 'audio/mpeg', note: 'evidence', submittedAt: '2026-10-31T08:01:00Z' }
  const resolved = { ...dispute, status: 'RESOLVED', decision: 'REQUEST_REVISION', resolutionNote: 'revise', reviewedByUserId: creatorId, resolvedAt: '2026-10-31T08:02:00Z' }
  const tx = transport([{ data: [dispute] }, { data: [submission] }, { data: { submissionId, url: 'https://cdn.example.test/signed', expiresAt: '2026-10-31T09:00:00Z' } }, { data: resolved }])
  await tx.backend.milestoneDisputes('OPEN')
  await tx.backend.milestoneDisputeSubmissions(milestoneId)
  await tx.backend.milestoneSubmissionMedia(milestoneId, submissionId)
  await tx.backend.resolveMilestoneDispute(disputeId, { decision: 'REQUEST_REVISION', note: 'revise' })
  assert.equal(tx.calls[0].url, '/api/admin/milestone-disputes')
  assert.deepEqual(tx.calls[0].params, { status: 'OPEN' })
  assert.equal(tx.calls[1].url, `/api/milestones/${milestoneId}/submissions`)
  assert.equal(tx.calls[2].url, `/api/milestones/${milestoneId}/submissions/${submissionId}/media`)
  assert.deepEqual(JSON.parse(String(tx.calls[3].data)), { decision: 'REQUEST_REVISION', note: 'revise' })
})
