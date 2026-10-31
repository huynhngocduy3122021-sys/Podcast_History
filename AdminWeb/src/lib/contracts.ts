import { z } from 'zod'
import { textWithLimit } from './validation.ts'
import { pageSchema } from './pagination.ts'

export const loginSchema = z.object({
  identifier: textWithLimit(255, 'Tên đăng nhập hoặc email tối đa 255 ký tự').trim().min(1, 'Nhập tên đăng nhập hoặc email'),
  password: textWithLimit(72, 'Mật khẩu tối đa 72 ký tự').min(1, 'Nhập mật khẩu').refine(value => value.trim().length > 0, 'Nhập mật khẩu'),
})
export const userSchema = z.object({
  id: z.string(), username: z.string(), email: z.string(), displayName: z.string().nullable(), role: z.string(),
})
export const tokenSchema = z.object({
  accessToken: z.string().min(1), refreshToken: z.string().min(1), tokenType: z.literal('Bearer'),
  expiresIn: z.number().positive(), refreshExpiresIn: z.number().positive(), user: userSchema,
})
export const meSchema = z.object({ userId: z.string(), username: z.string(), email: z.string(), role: z.string() })
const count = z.number().int().nonnegative()
const dashboardMoney = z.union([
  z.string().regex(/^(?:\d+(?:\.\d*)?|\.\d+)$/, 'Số tiền không hợp lệ'),
  z.number().nonnegative(),
]).transform(value => String(value))
export const dashboardSchema = z.object({
  users: count, activeUsers: count, creators: count, pendingCreators: count,
  podcasts: count, pendingPodcasts: count, pendingReports: count,
  pendingWithdrawals: count, openDisputes: count,
  podcastStatuses: z.array(z.object({ status: z.string().nullable(), count })),
  collectedPayments: z.array(z.object({ currency: z.string(), amount: dashboardMoney })),
})
export type User = z.infer<typeof userSchema>
export type Tokens = z.infer<typeof tokenSchema>

export const notificationSchema = z.object({
  notificationId: z.string(),
  type: z.string().nullable(),
  title: z.string().nullable(),
  message: z.string().nullable(),
  read: z.boolean(),
  createdAt: z.string().nullable(),
  readAt: z.string().nullable(),
  payload: z.unknown().nullable().optional(),
})
export const notificationsPageSchema = pageSchema(notificationSchema)
export type Notification = z.infer<typeof notificationSchema>
export type NotificationsPage = z.infer<typeof notificationsPageSchema>
