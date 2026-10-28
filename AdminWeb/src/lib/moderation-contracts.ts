import { z } from 'zod'
import { pageSchema } from './pagination.ts'
import { textWithLimit } from './validation.ts'

const instant = z.iso.datetime({ offset: true })
const nullableText = z.string().nullable()
export const podcastStatusSchema = z.enum(['DRAFT', 'PENDING_REVIEW', 'APPROVED', 'PUBLISHED', 'REJECTED', 'HIDDEN', 'DELETED'])
export const reportStatusSchema = z.enum(['PENDING', 'UNDER_REVIEW', 'DISMISSED', 'RESOLVED'])
export const appealStatusSchema = z.enum(['PENDING', 'ACCEPTED', 'REJECTED'])
export const reportActionSchema = z.enum(['DISMISS', 'HIDE_CONTENT', 'DELETE_CONTENT'])
export const appealDecisionSchema = z.enum(['ACCEPT', 'REJECT'])
export const optionalModerationNoteSchema = z.object({ note: textWithLimit(5000, 'Ghi chú tối đa 5.000 ký tự').trim() })
export const moderationNoteSchema = z.object({ note: textWithLimit(5000, 'Ghi chú tối đa 5.000 ký tự').trim().min(1, 'Nhập lý do xử lý') })
export const resolveReportSchema = moderationNoteSchema.extend({ action: reportActionSchema })
export const resolveAppealSchema = moderationNoteSchema.extend({ decision: appealDecisionSchema })

export const reviewSchema = z.object({
  reviewId: z.uuid(), reviewerId: z.uuid(), reviewerName: nullableText,
  decision: z.string(), note: nullableText, reviewedAt: instant,
})
export const reviewsPageSchema = pageSchema(reviewSchema)
export const podcastSchema = z.object({
  podcastId: z.uuid(), creatorProfileId: z.uuid(), creatorChannelName: nullableText,
  categoryId: z.uuid(), categoryName: z.string(), seriesId: z.uuid().nullable(), seriesTitle: nullableText,
  title: z.string(), description: nullableText, mediaKey: nullableText, mediaType: nullableText,
  thumbnailUrl: nullableText, durationSeconds: z.number().int().nullable(), exclusive: z.boolean().nullable(),
  visibility: z.enum(['PUBLIC', 'MEMBERS_ONLY']), status: podcastStatusSchema, submittedAt: instant.nullable(),
})
export const podcastsPageSchema = pageSchema(podcastSchema)
export const podcastDetailSchema = z.object({ podcast: podcastSchema, reviews: z.array(reviewSchema) })
export const podcastReviewResultSchema = z.object({ podcastId: z.uuid(), status: podcastStatusSchema, note: nullableText, reviewedAt: instant })
export const podcastTranscriptSchema = z.object({
  transcriptId: z.uuid(), podcastId: z.uuid(), mediaKey: nullableText,
  status: z.string().min(1), language: nullableText, modelName: nullableText,
  fullText: nullableText, segments: z.unknown().nullable(), errorMessage: nullableText,
  processedAt: instant.nullable(), current: z.boolean(),
})
export const aiModerationSchema = z.object({
  moderationResultId: z.uuid(), podcastId: z.uuid(), transcriptId: z.uuid().nullable(),
  transcriptHash: nullableText, modelName: nullableText, modelVersion: nullableText,
  status: z.string().min(1), overallLabel: nullableText, recommendation: nullableText,
  confidenceScore: z.number().finite().min(0).max(1).nullable(), reason: nullableText, rawResult: z.unknown().nullable(),
  sourceHash: nullableText, mediaKey: nullableText, errorMessage: nullableText,
  processedAt: instant.nullable(), current: z.boolean(),
})
export const aiModerationPageSchema = pageSchema(aiModerationSchema)
export const referenceSchema = z.object({
  referenceId: z.uuid(), podcastId: z.uuid(), referenceType: z.string(), title: z.string(),
  author: nullableText, publisher: nullableText, publishedYear: z.number().int().nullable(),
  url: nullableText, fileKey: nullableText, citationText: nullableText, createdAt: instant.nullable(),
})
// Only HTTPS URLs returned by signing endpoints are used for media. Keys never
// become links; URLs remain in component memory and never enter the query cache.
const signedUrl = z.string().url().refine(value => {
  const url = new URL(value)
  return url.protocol === 'https:' && !url.username && !url.password
}, 'Đường dẫn xem tệp không hợp lệ.')
export const previewSchema = z.object({ podcastId: z.uuid(), videoUrl: signedUrl, expiresAt: instant })
export const referenceFileSchema = z.object({ referenceId: z.uuid(), downloadUrl: signedUrl, expiresAt: instant })
export const reportSchema = z.object({
  reportId: z.uuid(), reporterId: z.uuid(), reporterName: nullableText,
  targetType: z.enum(['PODCAST', 'COMMENT', 'LIVESTREAM']), targetId: z.uuid(),
  reasonCode: nullableText, description: nullableText, status: reportStatusSchema,
  assigneeId: z.uuid().nullable(), createdAt: instant, resolvedAt: instant.nullable(), reviews: z.array(reviewSchema),
})
export const reportsPageSchema = pageSchema(reportSchema)
export const appealSchema = z.object({
  appealId: z.uuid(), podcastId: z.uuid(), applicantId: z.uuid(), reason: z.string(),
  status: appealStatusSchema, note: nullableText, reviewerId: z.uuid().nullable(),
  createdAt: instant, resolvedAt: instant.nullable(),
})
export const appealsPageSchema = pageSchema(appealSchema)
export type Podcast = z.infer<typeof podcastSchema>
export type PodcastDetail = z.infer<typeof podcastDetailSchema>
export type Review = z.infer<typeof reviewSchema>
export type Reference = z.infer<typeof referenceSchema>
export type Report = z.infer<typeof reportSchema>
export type Appeal = z.infer<typeof appealSchema>
export type PodcastStatus = z.infer<typeof podcastStatusSchema>
export type ReportStatus = z.infer<typeof reportStatusSchema>
export type AppealStatus = z.infer<typeof appealStatusSchema>
export type ReportAction = z.infer<typeof reportActionSchema>
export type AppealDecision = z.infer<typeof appealDecisionSchema>
export type PodcastAction = 'approve' | 'reject' | 'hide' | 'restore' | 'delete'
export type PodcastTranscript = z.infer<typeof podcastTranscriptSchema>
export type AiModeration = z.infer<typeof aiModerationSchema>
