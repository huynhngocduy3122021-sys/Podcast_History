import test from 'node:test'
import assert from 'node:assert/strict'
import axios from 'axios'
import type { InternalAxiosRequestConfig } from 'axios'
import { createAdminApi } from '../src/lib/admin-api.ts'
import { adminKeys, creatorSystemPlanChangeConfirmed } from '../src/lib/admin-cache.ts'
import { creatorSystemPlanWriteSchema } from '../src/lib/admin-contracts.ts'
import { canAccess, sections } from '../src/lib/permissions.ts'
import { QueryClient } from '@tanstack/react-query'

const planId = '11111111-1111-4111-8111-111111111111'
const plan = {
  planId, code: 'PLUS', name: 'Creator Plus', description: 'Gói nâng cao', price: '50000.00', currency: 'VND',
  durationDays: 30, status: 'ACTIVE' as const,
  benefits: [{ key: 'UPLOAD_LIMIT', value: 'unlimited', description: 'Không giới hạn' }],
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

test('Creator System Plan schema enforces FREE and paid-plan rules', () => {
  const paid = { code: 'PLUS', name: 'Creator Plus', description: '', price: '50000.00', currency: 'VND', durationDays: 30, status: 'ACTIVE' as const, benefits: [{ key: 'UPLOAD_LIMIT', value: '3', description: '' }] }
  assert.equal(creatorSystemPlanWriteSchema.safeParse(paid).success, true)
  assert.equal(creatorSystemPlanWriteSchema.safeParse({ ...paid, code: 'FREE', price: '0', durationDays: null }).success, true)
  assert.equal(creatorSystemPlanWriteSchema.safeParse({ ...paid, code: 'FREE', price: '1' }).success, false)
  assert.equal(creatorSystemPlanWriteSchema.safeParse({ ...paid, code: 'PLUS', price: '0', durationDays: 30 }).success, false)
  assert.equal(creatorSystemPlanWriteSchema.safeParse({ ...paid, benefits: [{ key: 'bad-key', value: '3', description: '' }] }).success, false)
})

test('Creator System Plan client maps exact admin CRUD endpoints and statuses', async () => {
  const tx = transport([
    { data: [plan] }, { data: plan }, { data: plan, status: 201 }, { data: plan }, { data: { ...plan, status: 'INACTIVE' } },
  ])
  const values = { code: 'PLUS', name: 'Creator Plus', description: '', price: '50000.00', currency: 'VND', durationDays: 30, status: 'ACTIVE' as const, benefits: plan.benefits }
  await tx.backend.creatorSystemPlans()
  await tx.backend.creatorSystemPlan(planId)
  await tx.backend.saveCreatorSystemPlan(undefined, values)
  await tx.backend.saveCreatorSystemPlan(planId, values)
  await tx.backend.deactivateCreatorSystemPlan(planId)
  assert.equal(tx.calls[0].url, '/api/admin/creator-system-plans')
  assert.equal(tx.calls[1].url, `/api/admin/creator-system-plans/${planId}`)
  assert.equal(tx.calls[2].method, 'post')
  assert.equal(tx.calls[3].method, 'put')
  assert.equal(tx.calls[4].method, 'delete')
  assert.equal(tx.calls[4].data, undefined)
})

test('Creator System Plans are ADMIN-only and cache invalidation is scoped', async () => {
  assert.equal(canAccess('ADMIN', true), true)
  assert.equal(canAccess('STAFF', true), false)
  assert.equal(sections.find(section => section.path === '/creator-system-plans')?.adminOnly, true)
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  const admin = 'admin-1'
  const other = 'admin-2'
  client.setQueryData(adminKeys.creatorSystemPlans(admin), [plan])
  client.setQueryData(adminKeys.creatorSystemPlanDetail(admin, planId), plan)
  client.setQueryData(adminKeys.creatorSystemPlans(other), [plan])
  await creatorSystemPlanChangeConfirmed(client, admin, planId)
  assert.equal(client.getQueryState(adminKeys.creatorSystemPlans(admin))?.isInvalidated, true)
  assert.equal(client.getQueryState(adminKeys.creatorSystemPlanDetail(admin, planId))?.isInvalidated, true)
  assert.equal(client.getQueryState(adminKeys.creatorSystemPlans(other))?.isInvalidated, false)
})
