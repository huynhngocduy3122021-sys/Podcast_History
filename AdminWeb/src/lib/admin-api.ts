import type { AxiosInstance } from 'axios'
import { approveWithdrawalSchema, categoriesSchema, categoryFormSchema, categorySchema, completeWithdrawalSchema, contractSchema, contractsPageSchema, contractStatusSchema, creatorApplicationSchema, creatorApplicationsPageSchema, approveCreatorSchema, rejectCreatorSchema, auditsPageSchema, creatorSystemPlanSchema, creatorSystemPlansSchema, creatorSystemPlanWriteSchema, disputeSchema, disputesPageSchema, disputeStatusSchema, openDisputeSchema, paymentReconcileSchema, paymentRefundSchema, paymentSchema, paymentStatusSchema, paymentsPageSchema, planDeactivateSchema, planSchema, planWriteSchema, plansPageSchema, resolveDisputeSchema, staffCreateSchema, transactionsPageSchema, userAccessSchema, userProfileSchema, userRoleChangeSchema, userSchema, userVerificationSchema, usersPageSchema, uuidFilterSchema, walletsPageSchema, withdrawalNoteSchema, withdrawalReviewsPageSchema, withdrawalSchema, withdrawalStatusSchema, withdrawalsPageSchema, payoutAccountSchema, payoutAccountWriteSchema, payoutResultWriteSchema, payoutWithdrawalSchema, payoutWithdrawalsSchema, milestoneDisputeSchema, milestoneDisputesSchema, resolveMilestoneDisputeSchema, milestoneSubmissionsSchema, mediaUrlSchema } from './admin-contracts.ts'
import type { ApproveWithdrawal, CategoryForm, CompleteWithdrawal, CreatorStatus, AdminUserRole, PaymentReconcile, PaymentRefund, PaymentStatus, PlanWrite, WithdrawalNote, WithdrawalStatus, PayoutAccountWrite, PayoutResultWrite } from './admin-contracts.ts'
import { confirmedMutation } from './api-mutation.ts'

// Inject the existing authenticated transport; tests use an Axios adapter, not a second runtime client.
export function createAdminApi(client: Pick<AxiosInstance, 'get' | 'post' | 'put' | 'delete' | 'patch'>) {
  const applications = '/api/admin/creator-applications'
  const categories = '/api/admin/categories'
  const payments = '/api/admin/payments'
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
      return plansPageSchema.parse((await client.get('/api/admin/membership-plans', { params: { creatorId: creatorId || undefined, page: params.page, size: params.size }, signal })).data)
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
    async creatorSystemPlans(signal?: AbortSignal) {
      return creatorSystemPlansSchema.parse((await client.get('/api/admin/creator-system-plans', { signal })).data)
    },
    async creatorSystemPlan(planId: string, signal?: AbortSignal) {
      return creatorSystemPlanSchema.parse((await client.get(`/api/admin/creator-system-plans/${encodeURIComponent(planId)}`, { signal })).data)
    },
    async saveCreatorSystemPlan(planId: string | undefined, values: unknown) {
      const body = creatorSystemPlanWriteSchema.parse(values)
      return confirmedMutation(() => planId
        ? client.put(`/api/admin/creator-system-plans/${encodeURIComponent(planId)}`, body)
        : client.post('/api/admin/creator-system-plans', body), creatorSystemPlanSchema, planId ? 200 : 201,
        data => (!planId || data.planId === planId) && data.status === body.status)
    },
    async deactivateCreatorSystemPlan(planId: string) {
      return confirmedMutation(() => client.delete(`/api/admin/creator-system-plans/${encodeURIComponent(planId)}`), creatorSystemPlanSchema, 200,
        data => data.planId === planId && data.status === 'INACTIVE')
    },
    async auditLogs(params: { resourceType?: string; resourceId?: string; page: number; size: number }, signal?: AbortSignal) {
      const resourceId = uuidFilterSchema.parse(params.resourceId || '')
      return auditsPageSchema.parse((await client.get('/api/admin/audit-logs', { params: { ...params, resourceType: params.resourceType || undefined, resourceId: resourceId || undefined }, signal })).data)
    },
    async contracts(params: { status: string; page: number; size: number }, signal?: AbortSignal) {
      const status = params.status ? contractStatusSchema.parse(params.status) : ''
      return contractsPageSchema.parse((await client.get('/api/admin/contracts', { params: { status: status || undefined, page: params.page, size: params.size }, signal })).data)
    },
    async contract(contractId: string, signal?: AbortSignal) {
      return contractSchema.parse((await client.get(`/api/admin/contracts/${encodeURIComponent(contractId)}`, { signal })).data)
    },
    async openDispute(contractId: string, values: unknown) {
      const body = openDisputeSchema.parse(values)
      return confirmedMutation(() => client.post(`/api/admin/contracts/${encodeURIComponent(contractId)}/disputes`, body), disputeSchema, 201,
        data => data.contractId === contractId && data.status === 'OPEN')
    },
    async disputes(params: { status: string; page: number; size: number }, signal?: AbortSignal) {
      const status = params.status ? disputeStatusSchema.parse(params.status) : ''
      return disputesPageSchema.parse((await client.get('/api/admin/disputes', { params: { status: status || undefined, page: params.page, size: params.size }, signal })).data)
    },
    async dispute(disputeId: string, signal?: AbortSignal) {
      return disputeSchema.parse((await client.get(`/api/admin/disputes/${encodeURIComponent(disputeId)}`, { signal })).data)
    },
    async resolveDispute(disputeId: string, values: unknown) {
      const body = resolveDisputeSchema.parse(values)
      return confirmedMutation(() => client.post(`/api/admin/disputes/${encodeURIComponent(disputeId)}/resolve`, body), disputeSchema, 200,
        data => data.disputeId === disputeId && data.status === 'RESOLVED' && data.decision === body.decision)
    },
    async payments(params: { status: PaymentStatus | ''; page: number; size: number }, signal?: AbortSignal) {
      const status = params.status ? paymentStatusSchema.parse(params.status) : ''
      return paymentsPageSchema.parse((await client.get(payments, { params: { status: status || undefined, page: params.page, size: params.size }, signal })).data)
    },
    async payment(paymentId: string, signal?: AbortSignal) {
      return paymentSchema.parse((await client.get(`${payments}/${encodeURIComponent(paymentId)}`, { signal })).data)
    },
    async reconcilePayment(paymentId: string, values: PaymentReconcile) {
      const body = paymentReconcileSchema.parse(values)
      const expectedStatus = body.result
      return confirmedMutation(() => client.post(`${payments}/${encodeURIComponent(paymentId)}/reconcile`, body), paymentSchema, 200,
        data => data.paymentId === paymentId && data.status === expectedStatus)
    },
    async refundPayment(paymentId: string, values: PaymentRefund) {
      const body = paymentRefundSchema.parse(values)
      return confirmedMutation(() => client.post(`${payments}/${encodeURIComponent(paymentId)}/refund`, body), paymentSchema, 200,
        data => data.paymentId === paymentId && data.status === 'REFUNDED' && data.refundReference === body.refundReference)
    },
    async withdrawals(params: { status: WithdrawalStatus | ''; page: number; size: number }, signal?: AbortSignal) {
      const status = params.status ? withdrawalStatusSchema.parse(params.status) : ''
      return withdrawalsPageSchema.parse((await client.get('/api/admin/withdrawals', { params: { status: status || undefined, page: params.page, size: params.size }, signal })).data)
    },
    async withdrawal(withdrawalId: string, signal?: AbortSignal) {
      return withdrawalSchema.parse((await client.get(`/api/admin/withdrawals/${encodeURIComponent(withdrawalId)}`, { signal })).data)
    },
    async withdrawalReviews(withdrawalId: string, page: number, size: number, signal?: AbortSignal) {
      return withdrawalReviewsPageSchema.parse((await client.get(`/api/admin/withdrawals/${encodeURIComponent(withdrawalId)}/reviews`, { params: { page, size }, signal })).data)
    },
    async approveWithdrawal(withdrawalId: string, values: ApproveWithdrawal) {
      const body = approveWithdrawalSchema.parse(values)
      return confirmedMutation(() => client.post(`/api/admin/withdrawals/${encodeURIComponent(withdrawalId)}/approve`, body), withdrawalSchema, 200,
        data => data.withdrawalId === withdrawalId && data.status === 'PROCESSING' && data.fundsReserved)
    },
    async rejectWithdrawal(withdrawalId: string, values: WithdrawalNote) {
      const body = withdrawalNoteSchema.parse(values)
      return confirmedMutation(() => client.post(`/api/admin/withdrawals/${encodeURIComponent(withdrawalId)}/reject`, body), withdrawalSchema, 200,
        data => data.withdrawalId === withdrawalId && data.status === 'REJECTED' && !data.fundsReserved)
    },
    async completeWithdrawal(withdrawalId: string, values: CompleteWithdrawal) {
      const body = completeWithdrawalSchema.parse(values)
      return confirmedMutation(() => client.post(`/api/admin/withdrawals/${encodeURIComponent(withdrawalId)}/complete`, body), withdrawalSchema, 200,
        data => data.withdrawalId === withdrawalId && data.status === 'COMPLETED' && !data.fundsReserved && data.payoutReference === body.payoutReference)
    },
    async failWithdrawal(withdrawalId: string, values: WithdrawalNote) {
      const body = withdrawalNoteSchema.parse(values)
      return confirmedMutation(() => client.post(`/api/admin/withdrawals/${encodeURIComponent(withdrawalId)}/fail`, body), withdrawalSchema, 200,
        data => data.withdrawalId === withdrawalId && data.status === 'FAILED' && !data.fundsReserved)
    },
    async wallets(pageOrParams: number | { q?: string; role?: string; page: number; size: number }, sizeOrSignal?: number | AbortSignal, signal?: AbortSignal) {
      const params = typeof pageOrParams === 'number'
        ? { page: pageOrParams, size: sizeOrSignal as number, q: undefined, role: undefined }
        : pageOrParams
      const requestSignal = typeof sizeOrSignal === 'object' ? sizeOrSignal : signal
      const requestParams: { page: number; size: number; q?: string; role?: string } = { page: params.page, size: params.size }
      if (params.q) requestParams.q = params.q
      if (params.role) requestParams.role = params.role
      return walletsPageSchema.parse((await client.get('/api/admin/wallets', { params: requestParams, signal: requestSignal })).data)
    },
    async walletTransactions(params: { walletId?: string; status?: string; page: number; size: number }, signal?: AbortSignal) {
      const walletId = uuidFilterSchema.parse(params.walletId || '')
      return transactionsPageSchema.parse((await client.get('/api/admin/wallet-transactions', { params: { walletId: walletId || undefined, status: params.status || undefined, page: params.page, size: params.size }, signal })).data)
    },
    async pendingPayouts(signal?: AbortSignal) {
      return payoutWithdrawalsSchema.parse((await client.get('/api/admin/payouts/withdrawals/pending', { signal })).data)
    },
    async recordPayoutResult(withdrawalId: string, values: PayoutResultWrite) {
      const body = payoutResultWriteSchema.parse(values)
      return confirmedMutation(() => client.post(`/api/admin/payouts/withdrawals/${encodeURIComponent(withdrawalId)}/result`, body), payoutWithdrawalSchema, 200,
        data => data.withdrawalRequestId === withdrawalId && data.status === (body.result === 'SUCCESS' ? 'COMPLETED' : 'FAILED'))
    },
    async registerPayoutAccount(creatorProfileId: string, values: PayoutAccountWrite) {
      const body = payoutAccountWriteSchema.parse(values)
      return confirmedMutation(() => client.post(`/api/admin/payouts/creators/${encodeURIComponent(creatorProfileId)}/accounts`, body), payoutAccountSchema, 201,
        data => data.creatorProfileId === creatorProfileId && data.verified && data.active)
    },
    async milestoneDisputes(status = 'OPEN', signal?: AbortSignal) {
      return milestoneDisputesSchema.parse((await client.get('/api/admin/milestone-disputes', { params: { status }, signal })).data)
    },
    async milestoneDisputeSubmissions(milestoneId: string, signal?: AbortSignal) {
      return milestoneSubmissionsSchema.parse((await client.get(`/api/milestones/${encodeURIComponent(milestoneId)}/submissions`, { signal })).data)
    },
    async milestoneSubmissionMedia(milestoneId: string, submissionId: string) {
      return mediaUrlSchema.parse((await client.get(`/api/milestones/${encodeURIComponent(milestoneId)}/submissions/${encodeURIComponent(submissionId)}/media`)).data)
    },
    async resolveMilestoneDispute(disputeId: string, values: unknown) {
      const body = resolveMilestoneDisputeSchema.parse(values)
      return confirmedMutation(() => client.post(`/api/admin/milestone-disputes/${encodeURIComponent(disputeId)}/resolve`, body), milestoneDisputeSchema, 200,
        data => data.disputeId === disputeId && data.status === 'RESOLVED' && data.decision === body.decision)
    },
  }
}
