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
