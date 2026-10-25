import type { AxiosInstance } from 'axios'
import { confirmedMutation, confirmedNoContent } from './api-mutation.ts'
import { apiPrefix, type Role } from './permissions.ts'
import {
  appealsPageSchema, appealSchema, moderationNoteSchema, optionalModerationNoteSchema, podcastDetailSchema,
  podcastReviewResultSchema, podcastsPageSchema, previewSchema, referenceFileSchema, referenceSchema, reviewsPageSchema,
  reportsPageSchema, reportSchema, resolveAppealSchema, resolveReportSchema, podcastTranscriptSchema, aiModerationPageSchema,
  aiModerationSchema,
} from './moderation-contracts.ts'
import type { AppealDecision, PodcastAction, ReportAction } from './moderation-contracts.ts'

export function createModerationApi(client: Pick<AxiosInstance, 'get' | 'post' | 'delete'>, role: Role) {
  const prefix = apiPrefix(role)
  const podcasts = `${prefix}/podcasts`
  const reports = `${prefix}/reports`
  const appeals = `${prefix}/podcast-appeals`
  return {
    async podcasts(status: string, page: number, size: number, signal?: AbortSignal) {
      return podcastsPageSchema.parse((await client.get(`${podcasts}/page`, { params: { status: status || undefined, page, size }, signal })).data)
    },
    async podcast(id: string, signal?: AbortSignal) {
      return podcastDetailSchema.parse((await client.get(`${podcasts}/${encodeURIComponent(id)}`, { signal })).data)
    },
    async preview(id: string) {
      return previewSchema.parse((await client.get(`${podcasts}/${encodeURIComponent(id)}/preview`)).data)
    },
    async reviews(id: string, page = 0, size = 20, signal?: AbortSignal) {
      return reviewsPageSchema.parse((await client.get(`${podcasts}/${encodeURIComponent(id)}/reviews`, { params: { page, size }, signal })).data)
    },
    async references(id: string, signal?: AbortSignal) {
      return referenceSchema.array().parse((await client.get(`${podcasts}/${encodeURIComponent(id)}/references`, { signal })).data)
    },
    async transcript(id: string, signal?: AbortSignal) {
      return podcastTranscriptSchema.parse((await client.get(`${podcasts}/${encodeURIComponent(id)}/transcript`, { signal })).data)
    },
    async retryTranscript(id: string) {
      return podcastTranscriptSchema.parse((await client.post(`${podcasts}/${encodeURIComponent(id)}/transcript`)).data)
    },
    async aiModeration(id: string, page = 0, size = 20, signal?: AbortSignal) {
      return aiModerationPageSchema.parse((await client.get(`${podcasts}/${encodeURIComponent(id)}/ai-moderation`, { params: { page, size }, signal })).data)
    },
    async retryAiModeration(id: string) {
      return aiModerationSchema.parse((await client.post(`${podcasts}/${encodeURIComponent(id)}/ai-moderation`)).data)
    },
    async referenceFile(id: string, referenceId: string) {
      return referenceFileSchema.parse((await client.get(`${podcasts}/${encodeURIComponent(id)}/references/${encodeURIComponent(referenceId)}/file`)).data)
    },
    review(id: string, action: 'approve' | 'reject', note: string) {
      const body = (action === 'reject' ? moderationNoteSchema : optionalModerationNoteSchema).parse({ note })
      return confirmedMutation(() => client.post(`${podcasts}/${encodeURIComponent(id)}/${action}`, body), podcastReviewResultSchema, 200,
        data => data.podcastId === id && data.status === (action === 'approve' ? 'APPROVED' : 'REJECTED'))
    },
    moderate(id: string, action: Exclude<PodcastAction, 'approve' | 'reject'>, note: string) {
      const body = moderationNoteSchema.parse({ note })
      const request = action === 'delete'
        ? () => client.delete(`${podcasts}/${encodeURIComponent(id)}`, { data: body })
        : () => client.post(`${podcasts}/${encodeURIComponent(id)}/${action}`, body)
      return confirmedNoContent(request)
    },
    async reports(status: string, page: number, size: number, signal?: AbortSignal) {
      return reportsPageSchema.parse((await client.get(reports, { params: { status: status || undefined, page, size }, signal })).data)
    },
    async report(id: string, signal?: AbortSignal) {
      return reportSchema.parse((await client.get(`${reports}/${encodeURIComponent(id)}`, { signal })).data)
    },
    claimReport(id: string) {
      return confirmedMutation(() => client.post(`${reports}/${encodeURIComponent(id)}/claim`), reportSchema, 200, data => data.reportId === id && data.status === 'UNDER_REVIEW')
    },
    resolveReport(id: string, action: ReportAction, note: string) {
      const body = resolveReportSchema.parse({ action, note })
      return confirmedMutation(() => client.post(`${reports}/${encodeURIComponent(id)}/resolve`, body), reportSchema, 200,
        data => data.reportId === id && data.status === (action === 'DISMISS' ? 'DISMISSED' : 'RESOLVED'))
    },
    async appeals(status: string, page: number, size: number, signal?: AbortSignal) {
      return appealsPageSchema.parse((await client.get(appeals, { params: { status: status || undefined, page, size }, signal })).data)
    },
    async appeal(id: string, signal?: AbortSignal) {
      return appealSchema.parse((await client.get(`${appeals}/${encodeURIComponent(id)}`, { signal })).data)
    },
    resolveAppeal(id: string, decision: AppealDecision, note: string) {
      const body = resolveAppealSchema.parse({ decision, note })
      return confirmedMutation(() => client.post(`${appeals}/${encodeURIComponent(id)}/resolve`, body), appealSchema, 200,
        data => data.appealId === id && data.status === (decision === 'ACCEPT' ? 'ACCEPTED' : 'REJECTED'))
    },
  }
}
