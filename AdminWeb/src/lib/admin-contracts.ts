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
  durationDays: z.preprocess(value => typeof value === 'string' && value.trim() ? Number(value) : value,
    z.number().int().min(1, 'Thời hạn tối thiểu 1 ngày').max(3650, 'Thời hạn tối đa 3.650 ngày')),
  status: planStatusSchema,
})
export const planDeactivateSchema = z.object({ note: noteSchema })
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
