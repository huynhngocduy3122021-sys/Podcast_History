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
const revenueBreakdownSchema = z.object({
  currency: z.string().min(1),
  grossCollected: dashboardMoney,
  platformFees: dashboardMoney,
  netRevenue: dashboardMoney,
})
const revenueDetailSchema = z.object({
  paymentId: z.uuid(),
  sourceType: z.string().min(1),
  sourceLabel: z.string().min(1),
  amount: dashboardMoney,
  platformFee: dashboardMoney,
  netRevenue: dashboardMoney,
  currency: z.string().length(3),
  status: z.enum(['PAID', 'SUCCESS', 'COMPLETED']),
  paymentMethod: z.string().nullable(),
  provider: z.string().nullable(),
  providerTransactionId: z.string().nullable(),
  createdAt: z.string(),
  paidAt: z.string().nullable(),
  buyerId: z.uuid().nullable(),
  buyerName: z.string().nullable(),
  buyerEmail: z.string().nullable(),
  creatorProfileId: z.uuid().nullable(),
  creatorUserId: z.uuid().nullable(),
  creatorName: z.string().nullable(),
  creatorChannelName: z.string().nullable(),
  contractId: z.uuid().nullable(),
  requestId: z.uuid().nullable(),
  requestTitle: z.string().nullable(),
  stageId: z.uuid().nullable(),
  stageName: z.string().nullable(),
  stageOrder: z.number().int().nullable(),
  membershipPlanId: z.uuid().nullable(),
  membershipPlanName: z.string().nullable(),
})
export const dashboardSchema = z.object({
  users: count, activeUsers: count, creators: count, pendingCreators: count,
  podcasts: count, pendingPodcasts: count, pendingReports: count,
  pendingWithdrawals: count, openDisputes: count,
  podcastStatuses: z.array(z.object({ status: z.string().nullable(), count })),
  collectedPayments: z.array(z.object({ currency: z.string(), amount: dashboardMoney })),
  revenueBreakdown: z.array(revenueBreakdownSchema),
})
export type User = z.infer<typeof userSchema>
export type Tokens = z.infer<typeof tokenSchema>
export type Dashboard = z.infer<typeof dashboardSchema>
export type RevenueBreakdown = z.infer<typeof revenueBreakdownSchema>
export type RevenueDetail = z.infer<typeof revenueDetailSchema>
export const revenueDetailsPageSchema = pageSchema(revenueDetailSchema)
export type RevenueDetailsPage = z.infer<typeof revenueDetailsPageSchema>

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
