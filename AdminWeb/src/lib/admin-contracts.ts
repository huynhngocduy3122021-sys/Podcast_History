import { z } from 'zod'
import { pageSchema } from './pagination.ts'
import { textWithLimit } from './validation.ts'

export const creatorStatusSchema = z.enum(['PENDING', 'APPROVED', 'REJECTED'])
export const creatorApplicationSchema = z.object({
  applicationId: z.uuid(), applicantUserId: z.uuid(), username: z.string(), email: z.string(),
  channelName: z.string().nullable(), introduction: z.string().nullable(), portfolioUrl: z.string().nullable(),
  status: creatorStatusSchema, reviewNote: z.string().nullable(),
  submittedAt: z.string().nullable(), reviewedAt: z.string().nullable(),
})
export const creatorApplicationsPageSchema = pageSchema(creatorApplicationSchema)
export const approveCreatorSchema = z.object({ note: textWithLimit(2000, 'Ghi chú tối đa 2.000 ký tự').trim() })
export const rejectCreatorSchema = z.object({
  note: textWithLimit(2000, 'Ghi chú tối đa 2.000 ký tự').trim().min(1, 'Nhập lý do từ chối'),
})
export const categorySchema = z.object({
  categoryId: z.uuid(), name: z.string(), slug: z.string(), description: z.string().nullable(),
  active: z.boolean(), createdAt: z.string().nullable(), updatedAt: z.string().nullable(),
})
export const categoriesSchema = z.array(categorySchema)
export const categoryFormSchema = z.object({
  name: textWithLimit(120, 'Tên tối đa 120 ký tự').trim().min(1, 'Nhập tên danh mục'),
  slug: textWithLimit(140, 'Slug tối đa 140 ký tự').trim().min(1, 'Nhập slug')
    .refine(value => /[\p{L}\p{N}]/u.test(value), 'Slug phải chứa ít nhất một chữ hoặc số'),
  description: textWithLimit(10000, 'Mô tả tối đa 10.000 ký tự').trim(),
  active: z.boolean(),
})
export type CreatorStatus = z.infer<typeof creatorStatusSchema>
export type CreatorApplication = z.infer<typeof creatorApplicationSchema>
export type Category = z.infer<typeof categorySchema>
export type CategoryForm = z.infer<typeof categoryFormSchema>

const uuid = z.uuid()
export const uuidFilterSchema = z.union([z.literal(''), uuid])
const adminUserRoleSchema = z.enum(['LISTENER', 'CREATOR', 'STAFF', 'ADMIN'])
const noteSchema = textWithLimit(5000, 'Ghi chú tối đa 5.000 ký tự').trim().min(1, 'Nhập ghi chú')

export const userSchema = z.object({
  userId: uuid,
  username: z.string(),
  email: z.string(),
  displayName: z.string(),
  avatarUrl: z.string().nullable(),
  bio: z.string().nullable(),
  role: adminUserRoleSchema,
  active: z.boolean(),
  verified: z.boolean(),
  createdAt: z.string(),
  lastLoginAt: z.string().nullable(),
})
export const usersPageSchema = pageSchema(userSchema)
export const userProfileSchema = z.object({
  displayName: textWithLimit(120, 'Tên hiển thị tối đa 120 ký tự').trim().min(1, 'Nhập tên hiển thị'),
  avatarUrl: textWithLimit(2000, 'Ảnh đại diện tối đa 2.000 ký tự'),
  bio: textWithLimit(5000, 'Tiểu sử tối đa 5.000 ký tự'),
})
export const userAccessSchema = z.object({ active: z.boolean(), note: noteSchema })
export const userVerificationSchema = z.object({ verified: z.boolean(), note: noteSchema })
export const userRoleChangeSchema = z.object({
  role: adminUserRoleSchema.refine(value => value !== 'ADMIN', 'Không thể cấp role ADMIN qua API này'),
  note: noteSchema,
})
export const staffCreateSchema = z.object({
  username: textWithLimit(50, 'Username tối đa 50 ký tự').trim().min(3, 'Username tối thiểu 3 ký tự'),
  email: z.string().email('Email không hợp lệ').refine(value => value.length <= 255, 'Email tối đa 255 ký tự'),
  password: textWithLimit(72, 'Mật khẩu tối đa 72 ký tự').min(8, 'Mật khẩu tối thiểu 8 ký tự'),
  displayName: textWithLimit(120, 'Tên hiển thị tối đa 120 ký tự').trim().min(1, 'Nhập tên hiển thị'),
})

export const auditSchema = z.object({
  auditId: uuid,
  actorId: uuid,
  action: z.string(),
  resourceType: z.string(),
  resourceId: uuid,
  note: z.string().nullable(),
  createdAt: z.string(),
})
export const auditsPageSchema = pageSchema(auditSchema)

export const planStatusSchema = z.enum(['ACTIVE', 'INACTIVE'])
const decimalSchema = z.union([z.string(), z.number()]).transform(value => String(value))
export const planSchema = z.object({
  planId: uuid,
  creatorId: uuid,
  name: z.string(),
  description: z.string().nullable(),
  price: decimalSchema,
  currency: z.string(),
  durationDays: z.number().int().positive(),
  status: planStatusSchema,
})
export const plansPageSchema = pageSchema(planSchema)
const money = textWithLimit(13, 'Giá tối đa 10 chữ số và 2 chữ số thập phân').trim()
  .refine(value => /^\d{1,10}(?:\.\d{1,2})?$/.test(value), 'Giá phải là số dương, tối đa 2 chữ số thập phân')
  .refine(value => value.split('.').some((part, index) => index === 0 ? Number(part) > 0 : Number(part) > 0), 'Giá phải từ 0.01 trở lên')
export const planWriteSchema = z.object({
  creatorId: uuid,
  name: textWithLimit(150, 'Tên gói tối đa 150 ký tự').trim().min(1, 'Nhập tên gói'),
  description: textWithLimit(10000, 'Mô tả tối đa 10.000 ký tự'),
  price: money,
  currency: z.string().regex(/^[A-Z]{3}$/, 'Tiền tệ dùng 3 chữ in hoa'),
  durationDays: z.preprocess(value => typeof value === 'string' ? (value.trim() ? Number(value) : null) : value,
    z.number().int().min(1, 'Thời hạn tối thiểu 1 ngày').max(3650, 'Thời hạn tối đa 3.650 ngày')),
  status: planStatusSchema,
})
export const planDeactivateSchema = z.object({ note: noteSchema })

export const creatorSystemPlanStatusSchema = z.enum(['ACTIVE', 'INACTIVE'])
export const creatorSystemBenefitSchema = z.object({
  key: z.string(), value: z.string(), description: z.string().nullable(),
})
export const creatorSystemPlanSchema = z.object({
  planId: uuid,
  code: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  price: decimalSchema,
  currency: z.string().length(3),
  durationDays: z.number().int().nullable(),
  status: creatorSystemPlanStatusSchema,
  benefits: z.array(creatorSystemBenefitSchema),
})
export const creatorSystemPlansSchema = z.array(creatorSystemPlanSchema)
const creatorSystemBenefitWriteSchema = z.object({
  key: textWithLimit(60, 'Mã quyền lợi tối đa 60 ký tự').trim().min(1, 'Nhập mã quyền lợi')
    .regex(/^[A-Za-z][A-Za-z0-9_]*$/, 'Mã quyền lợi không hợp lệ'),
  value: textWithLimit(200, 'Giá trị quyền lợi tối đa 200 ký tự').trim().min(1, 'Nhập giá trị quyền lợi'),
  description: textWithLimit(500, 'Mô tả quyền lợi tối đa 500 ký tự'),
})
const creatorSystemPrice = textWithLimit(13, 'Giá tối đa 10 chữ số và 2 chữ số thập phân').trim()
  .refine(value => /^\d{1,10}(?:\.\d{1,2})?$/.test(value), 'Giá phải là số không âm, tối đa 2 chữ số thập phân')
export const creatorSystemPlanWriteSchema = z.object({
  code: textWithLimit(60, 'Mã gói tối đa 60 ký tự').trim().regex(/^[A-Za-z][A-Za-z0-9_]{1,59}$/, 'Mã gói không hợp lệ'),
  name: textWithLimit(150, 'Tên gói tối đa 150 ký tự').trim().min(1, 'Nhập tên gói'),
  description: textWithLimit(10000, 'Mô tả tối đa 10.000 ký tự'),
  price: creatorSystemPrice,
  currency: z.string().regex(/^[A-Z]{3}$/, 'Tiền tệ dùng 3 chữ in hoa'),
  durationDays: z.preprocess(value => typeof value === 'string' && value.trim() ? Number(value) : value,
    z.number().int().min(1, 'Thời hạn tối thiểu 1 ngày').max(3650, 'Thời hạn tối đa 3.650 ngày').nullable()),
  status: creatorSystemPlanStatusSchema,
  benefits: z.array(creatorSystemBenefitWriteSchema).max(30, 'Tối đa 30 quyền lợi'),
}).superRefine((value, context) => {
  const isFree = value.code.trim().toUpperCase() === 'FREE'
  if (isFree && (value.price !== '0' || value.durationDays !== null || value.status !== 'ACTIVE')) {
    context.addIssue({ code: 'custom', path: ['price'], message: 'Gói FREE phải có giá 0, không thời hạn và luôn ACTIVE' })
  }
  if (!isFree && (Number(value.price) <= 0 || value.durationDays === null)) {
    context.addIssue({ code: 'custom', path: ['price'], message: 'Gói trả phí cần giá dương và thời hạn' })
  }
})
export type CreatorSystemPlan = z.infer<typeof creatorSystemPlanSchema>
export type CreatorSystemPlanWrite = z.infer<typeof creatorSystemPlanWriteSchema>

export const paymentStatusSchema = z.enum(['PENDING', 'PAID', 'FAILED', 'REFUNDED', 'SUCCESS', 'COMPLETED'])
export const paymentSchema = z.object({
  paymentId: uuid,
  userId: uuid,
  subscriptionId: uuid.nullable(),
  requestId: uuid.nullable(),
  stageId: uuid.nullable(),
  amount: decimalSchema,
  currency: z.string().length(3),
  status: paymentStatusSchema,
  provider: z.string().nullable(),
  providerTransactionId: z.string().nullable(),
  createdAt: z.string(),
  paidAt: z.string().nullable(),
  refundReference: z.string().nullable(),
  refundedAt: z.string().nullable(),
})
export const paymentsPageSchema = pageSchema(paymentSchema)
export const paymentReconcileResultSchema = z.enum(['PAID', 'FAILED'])
export const paymentReconcileSchema = z.object({
  result: paymentReconcileResultSchema,
  providerTransactionId: textWithLimit(180, 'Mã giao dịch tối đa 180 ký tự').trim().optional(),
  note: noteSchema,
}).superRefine((value, ctx) => {
  if (value.result === 'PAID' && !value.providerTransactionId) {
    ctx.addIssue({ code: 'custom', path: ['providerTransactionId'], message: 'Nhập mã giao dịch đã đối soát khi ghi nhận PAID' })
  }
})
export const paymentRefundSchema = z.object({
  refundReference: textWithLimit(180, 'Mã hoàn tiền tối đa 180 ký tự').trim().min(1, 'Nhập mã hoàn tiền đã xác minh'),
  note: noteSchema,
})
export const withdrawalStatusSchema = z.enum(['PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'REJECTED'])
export const withdrawalSchema = z.object({
  withdrawalId: uuid,
  creatorId: uuid,
  walletId: uuid,
  amount: decimalSchema,
  currency: z.string().length(3),
  payoutMethod: z.string(),
  payoutAccountMasked: z.string(),
  status: withdrawalStatusSchema,
  fundsReserved: z.boolean(),
  payoutReference: z.string().nullable(),
  note: z.string().nullable(),
  requestedAt: z.string(),
  processedAt: z.string().nullable(),
})
export const withdrawalsPageSchema = pageSchema(withdrawalSchema)
export const withdrawalReviewSchema = z.object({
  reviewId: uuid,
  reviewerId: uuid,
  decision: z.string(),
  note: z.string().nullable(),
  reviewedAt: z.string(),
})
export const withdrawalReviewsPageSchema = pageSchema(withdrawalReviewSchema)
export const payoutStatusSchema = z.enum(['PENDING', 'COMPLETED', 'FAILED'])
export const payoutWithdrawalSchema = z.object({
  withdrawalRequestId: uuid,
  creatorProfileId: uuid,
  amount: decimalSchema,
  currency: z.string().length(3),
  payoutMethod: z.string(),
  payoutAccountMasked: z.string(),
  payoutAccountReference: z.string().nullable(),
  status: payoutStatusSchema,
  requestedAt: z.string(),
  note: z.string().nullable(),
})
export const payoutWithdrawalsSchema = z.array(payoutWithdrawalSchema)
export const payoutResultSchema = z.enum(['SUCCESS', 'FAILED'])
export const payoutResultWriteSchema = z.object({
  result: payoutResultSchema,
  providerReference: textWithLimit(180, 'Mã giao dịch tối đa 180 ký tự').trim().optional(),
  note: textWithLimit(5000, 'Ghi chú tối đa 5.000 ký tự').trim().optional(),
}).superRefine((value, context) => {
  if (value.result === 'SUCCESS' && !value.providerReference) {
    context.addIssue({ code: 'custom', path: ['providerReference'], message: 'Nhập mã giao dịch khi ghi nhận thành công' })
  }
})
export const payoutAccountSchema = z.object({
  payoutAccountId: uuid,
  creatorProfileId: uuid,
  payoutMethod: z.string(),
  accountMasked: z.string(),
  currency: z.string().length(3),
  verified: z.boolean(),
  active: z.boolean(),
})
export const payoutAccountWriteSchema = z.object({
  payoutMethod: textWithLimit(40, 'Phương thức tối đa 40 ký tự').trim().min(1, 'Nhập phương thức nhận tiền'),
  accountReference: textWithLimit(255, 'Tài khoản tối đa 255 ký tự').trim().min(1, 'Nhập tham chiếu tài khoản'),
  accountMasked: textWithLimit(160, 'Tài khoản hiển thị tối đa 160 ký tự').trim().min(1, 'Nhập tài khoản đã che'),
  currency: z.string().regex(/^[A-Za-z]{3}$/, 'Tiền tệ dùng 3 chữ cái'),
})
export const walletSchema = z.object({
  walletId: uuid,
  userId: uuid,
  username: z.string().optional(),
  email: z.string().optional(),
  displayName: z.string().optional(),
  role: z.string().optional(),
  active: z.boolean().optional(),
  verified: z.boolean().optional(),
  availableBalance: decimalSchema,
  heldBalance: decimalSchema.optional(),
  totalBalance: decimalSchema.optional(),
  currency: z.string().length(3),
  status: z.string(),
  createdAt: z.string().optional(),
  updatedAt: z.string().optional(),
})
export const walletsPageSchema = pageSchema(walletSchema)
export const transactionSchema = z.object({
  transactionId: uuid,
  walletId: uuid.nullable(),
  withdrawalId: uuid.nullable(),
  paymentId: uuid.nullable(),
  type: z.string(),
  direction: z.string(),
  amount: decimalSchema,
  currency: z.string().length(3),
  status: z.string(),
  referenceCode: z.string().nullable(),
  balanceAfter: decimalSchema.nullable(),
  createdAt: z.string(),
})
export const transactionsPageSchema = pageSchema(transactionSchema)
export const contractStatusSchema = z.string().min(1)
export const contractStageSchema = z.object({
  stageId: uuid,
  name: z.string(),
  order: z.number().int().nonnegative(),
  status: z.string(),
})
export const contractSchema = z.object({
  contractId: uuid,
  listenerId: uuid,
  creatorId: uuid,
  status: contractStatusSchema,
  createdAt: z.string(),
  stages: z.array(contractStageSchema),
})
export const contractsPageSchema = pageSchema(contractSchema)
export const disputeStatusSchema = z.string().min(1)
export const disputeDecisionSchema = z.enum(['RESUME_CONTRACT', 'CANCEL_CONTRACT', 'COMPLETE_CONTRACT', 'LISTENER_WINS', 'CREATOR_WINS'])
export const disputeSchema = z.object({
  disputeId: uuid,
  contractId: uuid,
  openedById: uuid,
  reason: z.string(),
  previousContractStatus: z.string(),
  status: disputeStatusSchema,
  decision: z.string().nullable(),
  note: z.string().nullable(),
  reviewerId: uuid.nullable(),
  createdAt: z.string(),
  resolvedAt: z.string().nullable(),
  responseDeadlineAt: z.string().nullable().optional(),
  opponentConfirmedAt: z.string().nullable().optional(),
  listenerWinAction: z.string().nullable().optional(),
})
export const disputesPageSchema = pageSchema(disputeSchema)
export const openDisputeSchema = z.object({ note: noteSchema })
export const milestoneDisputeDecisionSchema = z.enum(['APPROVE_MILESTONE', 'REQUEST_REVISION', 'LISTENER_WINS', 'CREATOR_WINS'])
export const milestoneDisputeSchema = z.object({
  disputeId: uuid,
  milestoneId: uuid,
  raisedByUserId: uuid,
  reason: z.string(),
  status: z.string(),
  decision: z.string().nullable(),
  resolutionNote: z.string().nullable(),
  reviewedByUserId: uuid.nullable(),
  createdAt: z.string(),
  resolvedAt: z.string().nullable(),
  responseDeadlineAt: z.string().nullable(),
  opponentConfirmedAt: z.string().nullable(),
  listenerWinAction: z.string().nullable(),
})
export const milestoneDisputesSchema = z.array(milestoneDisputeSchema)
export const resolveDisputeSchema = z.object({ decision: disputeDecisionSchema, note: noteSchema })
export const resolveMilestoneDisputeSchema = z.object({ decision: milestoneDisputeDecisionSchema, note: noteSchema })
export const milestoneSubmissionSchema = z.object({
  submissionId: uuid,
  milestoneId: uuid,
  revisionNumber: z.number().int().positive(),
  objectKey: z.string().nullable(),
  publicUrl: z.string().nullable(),
  contentType: z.string().nullable(),
  note: z.string().nullable(),
  submittedAt: z.string(),
})
export const milestoneSubmissionsSchema = z.array(milestoneSubmissionSchema)
export const mediaUrlSchema = z.object({ submissionId: uuid, url: z.string().url(), expiresAt: z.string() })
export const approveWithdrawalSchema = z.object({ payoutAccountVerified: z.literal(true), note: noteSchema })
export const withdrawalNoteSchema = z.object({ note: noteSchema })
export const completeWithdrawalSchema = z.object({
  payoutReference: textWithLimit(180, 'Mã chuyển khoản tối đa 180 ký tự').trim().min(1, 'Nhập mã chuyển khoản đã xác minh'),
  note: noteSchema,
})
export type AdminUserRole = z.infer<typeof adminUserRoleSchema>
export type AdminUser = z.infer<typeof userSchema>
export type UserProfile = z.infer<typeof userProfileSchema>
export type StaffCreate = z.infer<typeof staffCreateSchema>
export type UserAccess = z.infer<typeof userAccessSchema>
export type UserVerification = z.infer<typeof userVerificationSchema>
export type UserRoleChange = z.infer<typeof userRoleChangeSchema>
export type AuditItem = z.infer<typeof auditSchema>
export type MembershipPlan = z.infer<typeof planSchema>
export type PlanWrite = z.infer<typeof planWriteSchema>
export type PaymentStatus = z.infer<typeof paymentStatusSchema>
export type Payment = z.infer<typeof paymentSchema>
export type PaymentReconcile = z.infer<typeof paymentReconcileSchema>
export type PaymentRefund = z.infer<typeof paymentRefundSchema>
export type WithdrawalStatus = z.infer<typeof withdrawalStatusSchema>
export type Withdrawal = z.infer<typeof withdrawalSchema>
export type WithdrawalReview = z.infer<typeof withdrawalReviewSchema>
export type PayoutWithdrawal = z.infer<typeof payoutWithdrawalSchema>
export type PayoutResultWrite = z.infer<typeof payoutResultWriteSchema>
export type PayoutAccountWrite = z.infer<typeof payoutAccountWriteSchema>
export type Wallet = z.infer<typeof walletSchema>
export type Transaction = z.infer<typeof transactionSchema>
export type ContractStatus = z.infer<typeof contractStatusSchema>
export type ContractStage = z.infer<typeof contractStageSchema>
export type Contract = z.infer<typeof contractSchema>
export type DisputeStatus = z.infer<typeof disputeStatusSchema>
export type DisputeDecision = z.infer<typeof disputeDecisionSchema>
export type Dispute = z.infer<typeof disputeSchema>
export type OpenDispute = z.infer<typeof openDisputeSchema>
export type ResolveDispute = z.infer<typeof resolveDisputeSchema>
export type MilestoneDispute = z.infer<typeof milestoneDisputeSchema>
export type ResolveMilestoneDispute = z.infer<typeof resolveMilestoneDisputeSchema>
export type ApproveWithdrawal = z.infer<typeof approveWithdrawalSchema>
export type WithdrawalNote = z.infer<typeof withdrawalNoteSchema>
export type CompleteWithdrawal = z.infer<typeof completeWithdrawalSchema>

export function canReviewApplication(role: unknown, status: CreatorStatus) {
  return role === 'ADMIN' && status === 'PENDING'
}

export function safePortfolioUrl(value: string | null): string | undefined {
  if (!value) return undefined
  try {
    const url = new URL(value)
    return ['http:', 'https:'].includes(url.protocol) ? url.href : undefined
  } catch { return undefined }
}
