import type { AxiosInstance } from 'axios'
import { categoriesSchema, categoryFormSchema, categorySchema, creatorApplicationSchema, creatorApplicationsPageSchema, approveCreatorSchema, rejectCreatorSchema, auditsPageSchema, planDeactivateSchema, planSchema, planWriteSchema, plansPageSchema, staffCreateSchema, userAccessSchema, userProfileSchema, userRoleChangeSchema, userSchema, userVerificationSchema, usersPageSchema, uuidFilterSchema } from './admin-contracts.ts'
import type { CategoryForm, CreatorStatus, AdminUserRole, PlanWrite } from './admin-contracts.ts'
import { confirmedMutation } from './api-mutation.ts'

// Inject the existing authenticated transport; tests use an Axios adapter, not a second runtime client.
export function createAdminApi(client: Pick<AxiosInstance, 'get' | 'post' | 'put' | 'delete' | 'patch'>) {
  const applications = '/api/admin/creator-applications'
  const categories = '/api/admin/categories'
  return {
    async applications(status: CreatorStatus | '', page: number, size: number, signal?: AbortSignal) {
      return creatorApplicationsPageSchema.parse((await client.get(applications, { params: { status: status || undefined, page, size }, signal })).data)
    },
    async application(applicationId: string, signal?: AbortSignal) {
      return creatorApplicationSchema.parse((await client.get(`${applications}/${encodeURIComponent(applicationId)}`, { signal })).data)
    },
    async review(applicationId: string, decision: 'approve' | 'reject', values: { note: string }) {
      const body = (decision === 'reject' ? rejectCreatorSchema : approveCreatorSchema).parse(values)
      return confirmedMutation(() => client.post(`${applications}/${encodeURIComponent(applicationId)}/${decision}`, body), creatorApplicationSchema, 200,
        data => data.applicationId === applicationId && data.status === (decision === 'approve' ? 'APPROVED' : 'REJECTED'))
    },
    async categories(signal?: AbortSignal) {
      return categoriesSchema.parse((await client.get(categories, { signal })).data)
    },
    async saveCategory(categoryId: string | undefined, values: CategoryForm) {
      const body = categoryFormSchema.parse(values)
      return confirmedMutation(() => categoryId
        ? client.put(`${categories}/${encodeURIComponent(categoryId)}`, body)
        : client.post(categories, body), categorySchema, categoryId ? 200 : 201,
        data => (!categoryId || data.categoryId === categoryId) && data.active === body.active && data.name === body.name)
    },
    async deactivateCategory(categoryId: string) {
      return confirmedMutation(() => client.delete(`${categories}/${encodeURIComponent(categoryId)}`), categorySchema, 200,
        data => data.categoryId === categoryId && !data.active)
    },
    async users(params: { q?: string; role?: AdminUserRole | ''; active?: boolean; page: number; size: number }, signal?: AbortSignal) {
      return usersPageSchema.parse((await client.get('/api/admin/users', { params: { ...params, q: params.q || undefined, role: params.role || undefined, active: params.active, page: params.page, size: params.size }, signal })).data)
    },
    async user(userId: string, signal?: AbortSignal) {
      return userSchema.parse((await client.get(`/api/admin/users/${encodeURIComponent(userId)}`, { signal })).data)
    },
    async updateUser(userId: string, values: unknown) {
      const body = userProfileSchema.parse(values)
      return confirmedMutation(() => client.patch(`/api/admin/users/${encodeURIComponent(userId)}`, body), userSchema, 200,
        data => data.userId === userId)
    },
    async changeAccess(userId: string, values: unknown) {
      const body = userAccessSchema.parse(values)
      return confirmedMutation(() => client.patch(`/api/admin/users/${encodeURIComponent(userId)}/access`, body), userSchema, 200,
        data => data.userId === userId && data.active === body.active)
    },
    async changeVerification(userId: string, values: unknown) {
      const body = userVerificationSchema.parse(values)
      return confirmedMutation(() => client.patch(`/api/admin/users/${encodeURIComponent(userId)}/verification`, body), userSchema, 200,
        data => data.userId === userId && data.verified === body.verified)
    },
    async changeRole(userId: string, values: unknown) {
      const body = userRoleChangeSchema.parse(values)
      return confirmedMutation(() => client.patch(`/api/admin/users/${encodeURIComponent(userId)}/role`, body), userSchema, 200,
        data => data.userId === userId && data.role === body.role)
    },
    async revokeSessions(userId: string, values: unknown) {
      const body = planDeactivateSchema.parse(values)
      return confirmedMutation(() => client.post(`/api/admin/users/${encodeURIComponent(userId)}/revoke-sessions`, body), userSchema, 200,
        data => data.userId === userId)
    },
    async staff(page: number, size: number, signal?: AbortSignal) {
      return usersPageSchema.parse((await client.get('/api/admin/staff', { params: { page, size }, signal })).data)
    },
    async createStaff(values: unknown) {
      const body = staffCreateSchema.parse(values)
      return confirmedMutation(() => client.post('/api/admin/staff', body), userSchema, 201,
        data => data.role === 'STAFF' && data.active)
    },
    async plans(params: { creatorId?: string; status?: 'ACTIVE' | 'INACTIVE' | ''; page: number; size: number }, signal?: AbortSignal) {
      const creatorId = uuidFilterSchema.parse(params.creatorId || '')
      return plansPageSchema.parse((await client.get('/api/admin/membership-plans', { params: { ...params, creatorId: creatorId || undefined, status: params.status || undefined }, signal })).data)
    },
    async plan(planId: string, signal?: AbortSignal) {
      return planSchema.parse((await client.get(`/api/admin/membership-plans/${encodeURIComponent(planId)}`, { signal })).data)
    },
    async savePlan(planId: string | undefined, values: PlanWrite) {
      const body = planWriteSchema.parse(values)
      return confirmedMutation(() => planId
        ? client.put(`/api/admin/membership-plans/${encodeURIComponent(planId)}`, body)
        : client.post('/api/admin/membership-plans', body), planSchema, planId ? 200 : 201,
        data => (!planId || data.planId === planId) && data.creatorId === body.creatorId && data.status === body.status)
    },
    async deactivatePlan(planId: string, values: unknown) {
      const body = planDeactivateSchema.parse(values)
      return confirmedMutation(() => client.delete(`/api/admin/membership-plans/${encodeURIComponent(planId)}`, { data: body }), planSchema, 200,
        data => data.planId === planId && data.status === 'INACTIVE')
    },
    async auditLogs(params: { resourceType?: string; resourceId?: string; page: number; size: number }, signal?: AbortSignal) {
      const resourceId = uuidFilterSchema.parse(params.resourceId || '')
      return auditsPageSchema.parse((await client.get('/api/admin/audit-logs', { params: { ...params, resourceType: params.resourceType || undefined, resourceId: resourceId || undefined }, signal })).data)
    },
  }
}
