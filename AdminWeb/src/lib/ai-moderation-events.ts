import type { AiModeration } from './moderation-contracts.ts'

const emitted = new Map<string, number>()

export function currentAiModeration(items: AiModeration[] | undefined) {
  return items?.find(item => item.current) ?? items?.[0]
}

export function aiModerationSignature(item: AiModeration) {
  return [item.moderationResultId, item.status, item.overallLabel ?? '', item.recommendation ?? '', item.processedAt ?? '', item.errorMessage ?? ''].join('|')
}

export function shouldNotifyAiModeration(podcastId: string, signature: string) {
  const key = `${podcastId}:${signature}`
  if (emitted.has(key)) return false
  emitted.set(key, Date.now())
  if (emitted.size > 500) {
    const oldest = [...emitted.entries()].sort((a, b) => a[1] - b[1]).slice(0, emitted.size - 400)
    for (const [entry] of oldest) emitted.delete(entry)
  }
  return true
}

export function aiStatusLabel(status: string) {
  return ({ PENDING: 'Đang chờ xử lý', PROCESSING: 'Đang phân tích', COMPLETED: 'Đã có kết quả', FAILED: 'Xử lý thất bại', SKIPPED: 'Đã bỏ qua' } as Record<string, string>)[status] ?? status
}
