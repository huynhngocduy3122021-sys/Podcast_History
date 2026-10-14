import { isRole } from './permissions.ts'
import type { Role } from './permissions.ts'
import type { Appeal, AppealDecision, Podcast, PodcastAction, Report, ReportAction } from './moderation-contracts.ts'

export function canModeratePodcast(role: unknown, status: Podcast['status'], action: PodcastAction) {
  if (!isRole(role)) return false
  if (action === 'approve' || action === 'reject') return status === 'PENDING_REVIEW'
  if (action === 'restore') return status === 'HIDDEN'
  return status !== 'DELETED'
}
export function canHandleReport(role: unknown, actorId: string | undefined, report: Report) {
  return isRole(role) && !!actorId && ['PENDING', 'UNDER_REVIEW'].includes(report.status)
    && (role === 'ADMIN' || !report.assigneeId || report.assigneeId === actorId)
}
export function reportActions(role: unknown, actorId: string | undefined, report: Report, podcast?: Podcast): ReportAction[] {
  if (!canHandleReport(role, actorId, report)) return []
  if (report.targetType === 'LIVESTREAM') return ['DISMISS']
  if (report.targetType === 'PODCAST' && (!podcast || podcast.podcastId !== report.targetId || !['APPROVED', 'PUBLISHED', 'HIDDEN'].includes(podcast.status))) return ['DISMISS']
  return ['DISMISS', 'HIDE_CONTENT', 'DELETE_CONTENT']
}
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
export function isPodcastReportTarget(report: Pick<Report, 'targetType' | 'targetId'>) {
  return report.targetType === 'PODCAST' && uuidPattern.test(report.targetId)
}
export function reportCacheKeys(userId: string | undefined, report: Pick<Report, 'targetType' | 'targetId'>) {
  return {
    reports: ['moderation-reports', userId] as const,
    dashboard: ['dashboard', userId] as const,
    podcasts: isPodcastReportTarget(report)
      ? [['moderation-podcasts', userId] as const, ['moderation-podcast', userId, report.targetId] as const]
      : [],
  }
}
export function canResolveAppeal(role: unknown, appeal: Appeal, decision: AppealDecision, podcast?: Podcast) {
  if (!isRole(role) || appeal.status !== 'PENDING') return false
  return decision === 'REJECT' || !!podcast && podcast.podcastId === appeal.podcastId && ['HIDDEN', 'REJECTED'].includes(podcast.status) && !!podcast.mediaKey?.trim()
}
export function sameModerator(current: { id: string; role: string } | null, expected: { id: string; role: Role }) {
  return current?.id === expected.id && current.role === expected.role
}
export function linkExpired(expiresAt: string, now = Date.now()) {
  return !Number.isFinite(Date.parse(expiresAt)) || Date.parse(expiresAt) <= now + 5000
}

export const podcastStatusLabels = { DRAFT: 'Bản nháp', PENDING_REVIEW: 'Chờ duyệt', APPROVED: 'Đã duyệt', PUBLISHED: 'Đã xuất bản', REJECTED: 'Đã từ chối', HIDDEN: 'Đã ẩn', DELETED: 'Đã gỡ' }
export const reportStatusLabels = { PENDING: 'Chờ xử lý', UNDER_REVIEW: 'Đang xử lý', DISMISSED: 'Đã bác bỏ', RESOLVED: 'Đã xử lý' }
export const appealStatusLabels = { PENDING: 'Chờ xử lý', ACCEPTED: 'Đã chấp nhận', REJECTED: 'Đã từ chối' }
export const targetLabels = { PODCAST: 'Podcast', COMMENT: 'Bình luận', LIVESTREAM: 'Livestream' }
export const reportActionLabels = { DISMISS: 'Bác bỏ báo cáo', HIDE_CONTENT: 'Ẩn nội dung', DELETE_CONTENT: 'Gỡ nội dung' }
export const podcastActionLabels = { approve: 'Duyệt podcast', reject: 'Từ chối podcast', hide: 'Ẩn podcast', restore: 'Đưa về chờ duyệt', delete: 'Gỡ podcast' }
export const moderationSuccessMessages = {
  approve: 'Đã duyệt podcast thành công. Podcast chưa được xuất bản.',
  reject: 'Đã từ chối podcast.',
  hide: 'Đã ẩn podcast.',
  restore: 'Đã chuyển podcast về chờ duyệt.',
  delete: 'Đã gỡ podcast.',
  claim: 'Đã nhận xử lý báo cáo.',
  reclaim: 'Đã chuyển báo cáo về bạn để xử lý.',
  DISMISS: 'Đã bác bỏ báo cáo vi phạm.',
  HIDE_CONTENT: 'Đã ẩn nội dung và xử lý báo cáo.',
  DELETE_CONTENT: 'Đã gỡ nội dung và xử lý báo cáo.',
  ACCEPT: 'Đã chấp nhận khiếu nại và chuyển podcast về chờ duyệt.',
  REJECT: 'Đã từ chối khiếu nại.',
} as const
