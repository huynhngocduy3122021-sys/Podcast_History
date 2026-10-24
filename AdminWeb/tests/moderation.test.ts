import test from 'node:test'
import assert from 'node:assert/strict'
import axios, { AxiosError } from 'axios'
import { createModerationApi } from '../src/lib/moderation-api.ts'
import { confirmedNoContent } from '../src/lib/api-mutation.ts'
import { canModeratePodcast, canResolveAppeal, isPodcastReportTarget, linkExpired, reportActions, reportCacheKeys, sameModerator } from '../src/lib/moderation-rules.ts'
import { moderationNoteSchema, podcastDetailSchema, previewSchema, resolveReportSchema } from '../src/lib/moderation-contracts.ts'

const podcastId = '11111111-1111-4111-8111-111111111111'
const reporterId = '22222222-2222-4222-8222-222222222222'
const review = { reviewId: '33333333-3333-4333-8333-333333333333', reviewerId: reporterId, reviewerName: 'Staff', decision: 'APPROVED', note: null, reviewedAt: '2026-10-14T10:00:00Z' }
const podcast = { podcastId, creatorProfileId: reporterId, creatorChannelName: 'Kênh thử', categoryId: reporterId, categoryName: 'Lịch sử', seriesId: null, seriesTitle: null, title: 'Podcast thử', description: null, mediaKey: 'private/object.mp4', mediaType: 'video/mp4', thumbnailUrl: null, durationSeconds: 10, exclusive: false, visibility: 'PUBLIC' as const, status: 'PENDING_REVIEW' as const, submittedAt: '2026-10-14T09:00:00Z' }
const report = { reportId: reporterId, reporterId, reporterName: 'Người báo cáo', targetType: 'PODCAST' as const, targetId: podcastId, reasonCode: 'COPYRIGHT', description: 'Mô tả', status: 'PENDING' as const, assigneeId: null, createdAt: '2026-10-14T09:00:00Z', resolvedAt: null, reviews: [] }
const appeal = { appealId: '44444444-4444-4444-8444-444444444444', podcastId, applicantId: reporterId, reason: 'Xin xem xét lại', status: 'PENDING' as const, note: null, reviewerId: null, createdAt: '2026-10-14T09:00:00Z', resolvedAt: null }

function transport(data: unknown, status = 200) {
  const calls: { url?: string; method?: string; params?: unknown; data?: unknown }[] = []
  const client = axios.create({ adapter: async config => { calls.push({ url: config.url, method: config.method, params: config.params, data: config.data }); return { data, status, statusText: '', headers: {}, config } } })
  return { api: createModerationApi(client, 'STAFF'), calls }
}

test('moderation contracts enforce 5,000 UTF-16 note units and verified signed HTTPS URLs', () => {
  assert.equal(moderationNoteSchema.safeParse({ note: 'x'.repeat(5000) }).success, true)
  assert.equal(moderationNoteSchema.safeParse({ note: 'x'.repeat(5001) }).success, false)
  assert.equal(resolveReportSchema.safeParse({ action: 'DISMISS', note: 'Lý do' }).success, true)
  assert.equal(previewSchema.safeParse({ podcastId, videoUrl: 'https://r2.example/signed?x=1', expiresAt: '2026-10-14T10:00:00Z' }).success, true)
  assert.equal(previewSchema.safeParse({ podcastId, videoUrl: 'http://r2.example/signed', expiresAt: '2026-10-14T10:00:00Z' }).success, false)
  assert.equal(podcastDetailSchema.safeParse({ podcast, reviews: [review] }).success, true)
})

test('state and role rules keep unsupported actions hidden', () => {
  assert.equal(canModeratePodcast('STAFF', 'PENDING_REVIEW', 'approve'), true)
  assert.equal(canModeratePodcast('ADMIN', 'APPROVED', 'approve'), false)
  assert.equal(canModeratePodcast('STAFF', 'DELETED', 'restore'), false)
  assert.deepEqual(reportActions('STAFF', reporterId, report), ['DISMISS'])
  assert.deepEqual(reportActions('STAFF', reporterId, report, { ...podcast, status: 'APPROVED' }), ['DISMISS', 'HIDE_CONTENT', 'DELETE_CONTENT'])
  assert.deepEqual(reportActions('STAFF', reporterId, { ...report, targetType: 'LIVESTREAM' }), ['DISMISS'])
  assert.equal(canResolveAppeal('STAFF', appeal, 'ACCEPT', { ...podcast, status: 'HIDDEN' }), true)
  assert.equal(canResolveAppeal('STAFF', appeal, 'ACCEPT', { ...podcast, status: 'APPROVED' }), false)
  assert.equal(canResolveAppeal('STAFF', { ...appeal, status: 'ACCEPTED' }, 'REJECT', podcast), false)
  assert.equal(linkExpired('2026-10-14T09:00:00Z', Date.parse('2026-10-14T09:01:00Z')), true)
  assert.equal(linkExpired('not-a-date'), true)
  assert.equal(isPodcastReportTarget(report), true)
  assert.equal(isPodcastReportTarget({ ...report, targetType: 'COMMENT' }), false)
  assert.equal(isPodcastReportTarget({ ...report, targetId: 'comment-id' }), false)
  assert.deepEqual(reportCacheKeys(reporterId, report), {
    reports: ['moderation-reports', reporterId],
    dashboard: ['dashboard', reporterId],
    podcasts: [['moderation-podcasts', reporterId], ['moderation-podcast', reporterId, podcastId]],
  })
  assert.deepEqual(reportCacheKeys(reporterId, { ...report, targetType: 'COMMENT' }).podcasts, [])
  assert.equal(sameModerator({ id: reporterId, role: 'STAFF' }, { id: reporterId, role: 'STAFF' }), true)
  assert.equal(sameModerator({ id: reporterId, role: 'STAFF' }, { id: reporterId, role: 'ADMIN' }), false)
})

test('shared API uses admin prefix, exact bodies and 204 actions without parsing a body', async () => {
  const list = transport({ content: [podcast], number: 0, size: 20, totalElements: 1, totalPages: 1 })
  await list.api.podcasts('PENDING_REVIEW', 0, 20)
  assert.equal(list.calls[0].url, '/api/admin/podcasts/page')
  assert.deepEqual(list.calls[0].params, { status: 'PENDING_REVIEW', page: 0, size: 20 })
  const detail = transport({ podcast, reviews: [review] })
  await detail.api.podcast(podcastId)
  assert.equal(detail.calls[0].url, `/api/admin/podcasts/${podcastId}`)
  const history = transport({ content: [review], number: 1, size: 20, totalElements: 21, totalPages: 2 })
  await history.api.reviews(podcastId, 1, 20)
  assert.equal(history.calls[0].url, `/api/admin/podcasts/${podcastId}/reviews`)
  assert.deepEqual(history.calls[0].params, { page: 1, size: 20 })
  const emptyHistory = transport({ content: [], number: 0, size: 20, totalElements: 0, totalPages: 0 })
  assert.equal((await emptyHistory.api.reviews(podcastId)).content.length, 0)
  await assert.rejects(transport({ content: [] }).api.reviews(podcastId))
  const reviewResult = transport({ podcastId, status: 'APPROVED', note: null, reviewedAt: '2026-10-14T10:00:00Z' })
  await reviewResult.api.review(podcastId, 'approve', '')
  assert.equal(reviewResult.calls[0].url, `/api/admin/podcasts/${podcastId}/approve`)
  assert.deepEqual(JSON.parse(String(reviewResult.calls[0].data)), { note: '' })
  const noContent = transport('', 204)
  await noContent.api.moderate(podcastId, 'hide', 'Vi phạm')
  assert.equal(noContent.calls[0].url, `/api/admin/podcasts/${podcastId}/hide`)
  assert.deepEqual(JSON.parse(String(noContent.calls[0].data)), { note: 'Vi phạm' })
  const reportApi = transport({ ...report, status: 'DISMISSED' })
  await reportApi.api.resolveReport(reporterId, 'DISMISS', 'Không đủ căn cứ')
  assert.equal(reportApi.calls[0].url, `/api/admin/reports/${reporterId}/resolve`)
  assert.deepEqual(JSON.parse(String(reportApi.calls[0].data)), { action: 'DISMISS', note: 'Không đủ căn cứ' })
  const admin = createModerationApi(axios.create({ adapter: async config => ({ data: { content: [], number: 0, size: 20, totalElements: 0, totalPages: 0 }, status: 200, statusText: '', headers: {}, config }) }), 'ADMIN')
  await admin.reports('', 0, 20)
})

test('claim validates the confirmed response and preserves 403, 404 and 409 errors', async () => {
  const success = transport({ ...report, status: 'UNDER_REVIEW' })
  const claimed = await success.api.claimReport(report.reportId)
  assert.equal(claimed.status, 'UNDER_REVIEW')
  assert.equal(success.calls[0].url, `/api/admin/reports/${report.reportId}/claim`)
  for (const status of [403, 404, 409]) {
    const client = axios.create({ adapter: async config => {
      throw new axios.AxiosError('request failed', undefined, config, undefined, {
        data: { timestamp: '2026-10-14T10:00:00Z', status, error: 'Error', message: 'business conflict' },
        status, statusText: '', headers: {}, config,
      })
    } })
    const api = createModerationApi(client, 'STAFF')
    await assert.rejects(api.claimReport(report.reportId), error => {
      assert.equal(axios.isAxiosError(error), true)
      assert.equal((error as AxiosError).response?.status, status)
      return true
    })
  }
})

test('session guard blocks stale moderation success after identity or role changes', () => {
  const expected = { id: reporterId, role: 'STAFF' as const }
  assert.equal(sameModerator({ id: '99999999-9999-4999-8999-999999999999', role: 'STAFF' }, expected), false)
  assert.equal(sameModerator({ id: reporterId, role: 'ADMIN' }, expected), false)
  assert.equal(sameModerator(expected, expected), true)
})

test('204 helper rejects unexpected response status', async () => {
  await assert.rejects(confirmedNoContent(async () => ({ data: {}, status: 200, statusText: '', headers: {}, config: {} as never })), /Chưa xác nhận/)
})
