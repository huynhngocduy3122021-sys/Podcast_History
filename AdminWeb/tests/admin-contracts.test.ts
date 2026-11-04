import test from 'node:test'
import assert from 'node:assert/strict'
import { approveCreatorSchema, rejectCreatorSchema, categoryFormSchema, creatorApplicationSchema, categoriesSchema, canReviewApplication, safePortfolioUrl } from '../src/lib/admin-contracts.ts'
import { pageSchema } from '../src/lib/pagination.ts'
import { notificationsPageSchema, dashboardSchema, loginSchema, revenueDetailsPageSchema } from '../src/lib/contracts.ts'
import { z } from 'zod'

test('login honors Java UTF-16 limits and preserves password whitespace', () => {
  const valid = { identifier: 'admin', password: ' password ' }
  assert.equal(loginSchema.parse(valid).password, valid.password)
  assert.equal(loginSchema.parse({ ...valid, identifier: '  admin  ' }).identifier, 'admin')
  for (const [field, limit] of [['identifier', 255], ['password', 72]] as const) {
    assert.equal(loginSchema.safeParse({ ...valid, [field]: 'x'.repeat(limit) }).success, true)
    assert.equal(loginSchema.safeParse({ ...valid, [field]: 'x'.repeat(limit + 1) }).success, false)
    assert.equal(loginSchema.safeParse({ ...valid, [field]: '😀'.repeat(Math.floor(limit / 2) + 1) }).success, false)
  }
  assert.equal(loginSchema.safeParse({ ...valid, password: '😀'.repeat(36) }).success, true)
  for (const field of ['identifier', 'password']) assert.equal(loginSchema.safeParse({ ...valid, [field]: '   ' }).success, false)
})

test('reject requires a nonblank note and both decisions honor the 2000 UTF-16 length limit', () => {
  for (const note of ['', ' \n\t ']) assert.equal(rejectCreatorSchema.safeParse({ note }).success, false)
  assert.deepEqual(rejectCreatorSchema.parse({ note: '  Cần bổ sung portfolio  ' }), { note: 'Cần bổ sung portfolio' })
  assert.equal(approveCreatorSchema.safeParse({ note: '' }).success, true)
  for (const schema of [approveCreatorSchema, rejectCreatorSchema]) {
    assert.equal(schema.safeParse({ note: 'x'.repeat(2000) }).success, true)
    assert.equal(schema.safeParse({ note: 'x'.repeat(2001) }).success, false)
    assert.equal(schema.safeParse({ note: '😀'.repeat(1001) }).success, false)
  }
})

test('category fields match DTO limits, required active and backend slug validity', () => {
  const valid = { name: 'Lịch sử', slug: 'Lịch sử 2026', description: '', active: false }
  assert.equal(categoryFormSchema.safeParse(valid).success, true)
  assert.equal(categoryFormSchema.parse({ ...valid, name: '  Lịch sử  ' }).name, 'Lịch sử')
  for (const [field, limit] of [['name', 120], ['slug', 140], ['description', 10000]] as const) {
    assert.equal(categoryFormSchema.safeParse({ ...valid, [field]: 'x'.repeat(limit) }).success, true)
    assert.equal(categoryFormSchema.safeParse({ ...valid, [field]: 'x'.repeat(limit + 1) }).success, false)
    assert.equal(categoryFormSchema.safeParse({ ...valid, [field]: '😀'.repeat(limit / 2 + 1) }).success, false)
  }
  for (const field of ['name', 'slug']) assert.equal(categoryFormSchema.safeParse({ ...valid, [field]: '  ' }).success, false)
  for (const slug of ['---', '!!!', '😀']) assert.equal(categoryFormSchema.safeParse({ ...valid, slug }).success, false)
  assert.equal(categoryFormSchema.safeParse({ ...valid, active: undefined }).success, false)
})

test('only ADMIN can review PENDING creator profiles', () => {
  for (const role of ['ADMIN', 'STAFF', 'LISTENER', 'CREATOR', undefined]) {
    for (const status of ['PENDING', 'APPROVED', 'REJECTED'] as const) {
      assert.equal(canReviewApplication(role, status), role === 'ADMIN' && status === 'PENDING')
    }
  }
})

test('Spring page retains pagination metadata and rejects a List or missing metadata', () => {
  const schema = pageSchema(z.string())
  const page = { content: [], number: 0, size: 20, totalElements: 0, totalPages: 0, last: true }
  assert.equal(schema.parse(page).totalPages, 0)
  assert.equal(schema.safeParse([]).success, false)
  assert.equal(schema.safeParse({ content: [] }).success, false)
  assert.equal(schema.safeParse({ ...page, number: -1 }).success, false)
  assert.equal(categoriesSchema.safeParse({ content: [] }).success, false)
})

test('new pagination schema does not change existing notification and dashboard mappings', () => {
  assert.deepEqual(notificationsPageSchema.parse({ content: [], number: 0, size: 20, totalElements: 0, totalPages: 0 }), { content: [], number: 0, size: 20, totalElements: 0, totalPages: 0 })
  assert.equal(dashboardSchema.safeParse({ users: 0, activeUsers: 0, creators: 0, pendingCreators: 0, podcasts: 0, pendingPodcasts: 0, pendingReports: 0, pendingWithdrawals: 0, openDisputes: 0, podcastStatuses: [], collectedPayments: [], revenueBreakdown: [] }).success, true)
  assert.equal(creatorApplicationSchema.safeParse({ applicationId: 'not-a-uuid' }).success, false)
})

test('dashboard revenue contract preserves decimal strings and nullable detail context', () => {
  const dashboard = dashboardSchema.parse({
    users: 1, activeUsers: 1, creators: 1, pendingCreators: 0, podcasts: 2, pendingPodcasts: 0,
    pendingReports: 0, pendingWithdrawals: 0, openDisputes: 0, podcastStatuses: [{ status: null, count: 1 }], collectedPayments: [],
    revenueBreakdown: [{ currency: 'VND', grossCollected: '100000000000000000.25', platformFees: 1200, netRevenue: '1200.00' }],
  })
  assert.equal(dashboard.revenueBreakdown[0].grossCollected, '100000000000000000.25')
  assert.equal(dashboard.revenueBreakdown[0].platformFees, '1200')
  const detail = revenueDetailsPageSchema.parse({
    content: [{
    paymentId: '11111111-1111-4111-8111-111111111111', sourceType: 'CONTRACT_STAGE', sourceLabel: 'Stage 1',
      amount: '50000', platformFee: '5000', netRevenue: '5000', currency: 'VND', status: 'PAID',
      paymentMethod: null, provider: 'INTERNAL', providerTransactionId: null, createdAt: '2026-11-04T00:00:00Z', paidAt: null,
      buyerId: null, buyerName: null, buyerEmail: null, creatorProfileId: null, creatorUserId: null,
      creatorName: null, creatorChannelName: null, contractId: null, requestId: null, requestTitle: null,
      stageId: null, stageName: null, stageOrder: null, membershipPlanId: null, membershipPlanName: null,
    }], number: 0, size: 20, totalElements: 1, totalPages: 1,
  })
  assert.equal(detail.content[0].buyerId, null)
  assert.equal(detail.content[0].netRevenue, '5000')
  for (const sourceType of ['MEMBERSHIP', 'CONTRACT_STAGE', 'CONTRACT_DISPUTE', 'CONTRACT_COMPENSATION', 'REQUEST', 'OTHER']) {
    assert.equal(revenueDetailsPageSchema.safeParse({ content: [{
      paymentId: '11111111-1111-4111-8111-111111111111', sourceType, sourceLabel: 'Source', amount: '1', platformFee: '0', netRevenue: '0', currency: 'VND', status: 'COMPLETED',
      paymentMethod: null, provider: null, providerTransactionId: null, createdAt: '2026-11-04T00:00:00Z', paidAt: null, buyerId: null, buyerName: null, buyerEmail: null,
      creatorProfileId: null, creatorUserId: null, creatorName: null, creatorChannelName: null, contractId: null, requestId: null, requestTitle: null, stageId: null, stageName: null, stageOrder: null, membershipPlanId: null, membershipPlanName: null,
    }], number: 0, size: 20, totalElements: 1, totalPages: 1 }).success, true)
  }
})

test('revenue details accepts only collected payment statuses and complete page metadata', () => {
  const base = {
    paymentId: '11111111-1111-4111-8111-111111111111', sourceType: 'OTHER', sourceLabel: 'Other',
    amount: '1', platformFee: '0', netRevenue: '0', currency: 'USD', paymentMethod: null, provider: null,
    providerTransactionId: null, createdAt: '2026-11-04T00:00:00Z', paidAt: null, buyerId: null, buyerName: null,
    buyerEmail: null, creatorProfileId: null, creatorUserId: null, creatorName: null, creatorChannelName: null,
    contractId: null, requestId: null, requestTitle: null, stageId: null, stageName: null, stageOrder: null,
    membershipPlanId: null, membershipPlanName: null,
  }
  for (const status of ['PAID', 'SUCCESS', 'COMPLETED'] as const) {
    assert.equal(revenueDetailsPageSchema.safeParse({ content: [{ ...base, status }], number: 0, size: 20, totalElements: 1, totalPages: 1 }).success, true)
  }
  assert.equal(revenueDetailsPageSchema.safeParse({ content: [{ ...base, status: 'PENDING' }], number: 0, size: 20, totalElements: 1, totalPages: 1 }).success, false)
  assert.equal(revenueDetailsPageSchema.safeParse({ content: [], number: 0, size: 20, totalElements: 0 }).success, false)
})

test('portfolio links allow HTTP(S), never executable or invalid URLs', () => {
  assert.equal(safePortfolioUrl('https://example.com/work'), 'https://example.com/work')
  for (const url of ['javascript:alert(1)', 'data:text/html,<script/>', 'file:///secret', 'invalid', null]) assert.equal(safePortfolioUrl(url), undefined)
})
