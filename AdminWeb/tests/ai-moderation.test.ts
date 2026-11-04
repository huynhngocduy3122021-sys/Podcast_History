import test from 'node:test'
import assert from 'node:assert/strict'
import axios from 'axios'
import { createModerationApi } from '../src/lib/moderation-api.ts'
import { aiModerationSchema, podcastTranscriptSchema } from '../src/lib/moderation-contracts.ts'
import { aiModerationSignature, aiStatusLabel, shouldNotifyAiModeration } from '../src/lib/ai-moderation-events.ts'

const podcastId = '11111111-1111-4111-8111-111111111111'
const transcriptId = '22222222-2222-4222-8222-222222222222'
const moderationResultId = '33333333-3333-4333-8333-333333333333'
const transcript = { transcriptId, podcastId, mediaKey: 'private/audio.mp4', status: 'COMPLETED', language: 'vi', modelName: 'whisper', fullText: 'Nội dung', segments: [], errorMessage: null, processedAt: '2026-10-24T10:00:00Z', current: true }
const ai = { moderationResultId, podcastId, transcriptId, transcriptHash: 'transcript-hash', modelName: 'gemini', modelVersion: '1', status: 'COMPLETED', overallLabel: 'SAFE', recommendation: 'APPROVE', confidenceScore: 0.98, reason: 'An toàn', rawResult: null, sourceHash: 'source-hash', mediaKey: 'private/audio.mp4', errorMessage: null, processedAt: '2026-10-24T10:01:00Z', current: true }

function transport(responses: Array<{ data?: unknown; status?: number }>) {
  const calls: Array<{ url?: string; method?: string; params?: unknown; data?: unknown }> = []
  const client = axios.create({ adapter: async config => {
    calls.push({ url: config.url, method: config.method, params: config.params, data: config.data })
    const next = responses.shift() ?? { data: ai }
    return { data: next.data, status: next.status ?? 200, statusText: 'OK', headers: {}, config }
  } })
  return { backend: createModerationApi(client, 'STAFF'), calls }
}

test('AI and transcript schemas follow the documented response fields', () => {
  assert.equal(podcastTranscriptSchema.safeParse(transcript).success, true)
  assert.equal(aiModerationSchema.safeParse(ai).success, true)
  assert.equal(aiModerationSchema.safeParse({ ...ai, confidenceScore: '0.98' }).success, false)
  assert.equal(aiModerationSchema.safeParse({ ...ai, confidenceScore: 1.01 }).success, false)
})

test('AI moderation API uses exact documented endpoints, pagination and empty retry bodies', async () => {
  const tx = transport([
    { data: transcript },
    { data: transcript },
    { data: { content: [ai], number: 0, size: 20, totalElements: 1, totalPages: 1 } },
    { data: ai },
  ])
  await tx.backend.transcript(podcastId)
  await tx.backend.retryTranscript(podcastId)
  await tx.backend.aiModeration(podcastId, 1, 20)
  await tx.backend.retryAiModeration(podcastId)
  assert.equal(tx.calls[0].url, `/api/admin/podcasts/${podcastId}/transcript`)
  assert.equal(tx.calls[0].method, 'get')
  assert.equal(tx.calls[1].method, 'post')
  assert.equal(tx.calls[1].data, undefined)
  assert.equal(tx.calls[2].url, `/api/admin/podcasts/${podcastId}/ai-moderation`)
  assert.deepEqual(tx.calls[2].params, { page: 1, size: 20 })
  assert.equal(tx.calls[3].method, 'post')
  assert.equal(tx.calls[3].data, undefined)
})

test('AI event signatures deduplicate repeated polling results', () => {
  const signature = aiModerationSignature(ai)
  assert.equal(shouldNotifyAiModeration(podcastId, signature), true)
  assert.equal(shouldNotifyAiModeration(podcastId, signature), false)
  assert.equal(aiStatusLabel('PROCESSING'), 'Đang phân tích')
})
