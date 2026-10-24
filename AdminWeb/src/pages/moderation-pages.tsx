import { Fragment, useMemo, useRef, useState } from 'react'
import type { ReactNode } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { RefreshCw, ExternalLink, Download, Eye, Check, X, EyeOff, RotateCcw, Trash2 } from 'lucide-react'
import { useAuth } from '../auth'
import { api, errorMessage, session } from '../lib/client'
import { extractApiError } from '../lib/api-error'
import { createModerationApi } from '../lib/moderation-api'
import { appealCacheKeys, canHandleReport, canModeratePodcast, canResolveAppeal, isPodcastReportTarget, linkExpired, moderationSuccessMessages, podcastActionLabels, podcastStatusLabels, reportActionLabels, reportActions, reportStatusLabels, reportCacheKeys, targetLabels, appealStatusLabels, sameModerator } from '../lib/moderation-rules'
import type { AppealDecision, PodcastAction, ReportAction } from '../lib/moderation-contracts'
import type { Role } from '../lib/permissions'
import { Button } from '../components/ui/button'
import { ConfirmDialog } from '../components/ui/confirm-dialog'
import { Pagination } from '../components/pagination'
import { EmptyState, ErrorState, LoadingState } from '../components/states'
import { useFeedback } from '../components/feedback'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { moderationNoteSchema, optionalModerationNoteSchema } from '../lib/moderation-contracts'
import { identityOf } from '../lib/identity'

const date = (value: string | null | undefined) => value ? new Date(value).toLocaleString('vi-VN') : '—'
const key = (name: string, userId: string | undefined, status: string, page: number) => [name, userId, status, page] as const
const sessionChangedMessage = 'Phiên đăng nhập đã thay đổi. Vui lòng tải lại dữ liệu trước khi tiếp tục.'
function requireCurrentModerator(expected: { id: string; role: Role }) {
  if (!sameModerator(session.getUser(), expected)) throw new Error(sessionChangedMessage)
}
function currentModerator() {
  const current = identityOf(session.getUser())
  return current && (current.role === 'ADMIN' || current.role === 'STAFF') ? current as { id: string; role: Role } : null
}

function NoteDialog({ fieldId, title, description, confirmLabel, schema, onConfirm, onOpenChange, destructive = false, children }: { fieldId: string; title: string; description: string; confirmLabel: string; schema: typeof moderationNoteSchema | typeof optionalModerationNoteSchema; onConfirm: (note: string) => Promise<void>; onOpenChange?: (open: boolean) => void; destructive?: boolean; children?: ReactNode }) {
  const form = useForm({ resolver: zodResolver(schema), defaultValues: { note: '' }, mode: 'onChange' })
  return <ConfirmDialog trigger={children ?? <Button>{confirmLabel}</Button>} title={title} description={description} confirmLabel={confirmLabel} destructive={destructive} confirmDisabled={schema === moderationNoteSchema && !form.formState.isValid} onOpenChange={open => { form.reset({ note: '' }); onOpenChange?.(open) }} onConfirm={async () => { if (!await form.trigger()) throw new Error('Vui lòng kiểm tra ghi chú.'); await onConfirm(form.getValues().note) }}>
    <label className="field-label" htmlFor={fieldId}>Ghi chú *</label><textarea id={fieldId} rows={5} maxLength={5000} className="field py-3" {...form.register('note')} aria-invalid={!!form.formState.errors.note} />
    {form.formState.errors.note && <p className="field-error">{form.formState.errors.note.message}</p>}<p className="mt-2 text-xs text-muted-foreground">Tối đa 5.000 ký tự.</p>
  </ConfirmDialog>
}

function PodcastAction({ podcastId, action, status, role, onDone }: { podcastId: string; action: PodcastAction; status: Parameters<typeof canModeratePodcast>[1]; role: string | undefined; onDone: () => Promise<void> }) {
  const notify = useFeedback(); const backend = useMemo(() => createModerationApi(api, role === 'ADMIN' ? 'ADMIN' : 'STAFF'), [role])
  const initiatingModerator = useRef<{ id: string; role: Role } | null>(null)
  const mutation = useMutation({ mutationFn: async (note: string) => { const expected = initiatingModerator.current; if (!expected) throw new Error(sessionChangedMessage); requireCurrentModerator(expected); if (action === 'approve' || action === 'reject') { await backend.review(podcastId, action, note); return } await backend.moderate(podcastId, action, note) }, onSuccess: async () => { const expected = initiatingModerator.current; if (!expected) return; requireCurrentModerator(expected); await onDone(); requireCurrentModerator(expected); notify(moderationSuccessMessages[action]) }, onError: async error => { const expected = initiatingModerator.current; if (extractApiError(error).outcomeUnknown && expected && sameModerator(session.getUser(), expected)) { try { await onDone() } catch { /* Keep the uncertain outcome visible to the operator. */ } } } })
  const optional = action === 'approve'
  return <NoteDialog fieldId={`podcast-${podcastId}-${action}-note`} schema={optional ? optionalModerationNoteSchema : moderationNoteSchema} title={`${podcastActionLabels[action]}?`} description={action === 'approve' ? 'Podcast sẽ chuyển sang trạng thái Đã duyệt và chưa được xuất bản.' : `Xác nhận ${podcastActionLabels[action].toLowerCase()}.`} confirmLabel={`Xác nhận ${podcastActionLabels[action].toLowerCase()}`} destructive={action === 'reject' || action === 'hide' || action === 'delete'} onOpenChange={open => { initiatingModerator.current = open ? currentModerator() : null }} onConfirm={note => mutation.mutateAsync(note)}>{<Button variant={action === 'approve' ? 'default' : 'outline'} disabled={mutation.isPending || !canModeratePodcast(role, status, action)}>{action === 'approve' ? <Check className="size-4" /> : action === 'reject' ? <X className="size-4" /> : action === 'hide' ? <EyeOff className="size-4" /> : action === 'restore' ? <RotateCcw className="size-4" /> : <Trash2 className="size-4" />}{podcastActionLabels[action]}</Button>}</NoteDialog>
}

function PodcastDetail({ id, role, onClose }: { id: string; role: string | undefined; onClose: () => void }) {
  const backend = useMemo(() => createModerationApi(api, role === 'ADMIN' ? 'ADMIN' : 'STAFF'), [role]); const client = useQueryClient(); const notify = useFeedback(); const { user } = useAuth(); const [preview, setPreview] = useState<{ url: string; expiresAt: string } | null>(null); const [historyPage, setHistoryPage] = useState(0)
  const detail = useQuery({ queryKey: ['moderation-podcast', user?.id, id], queryFn: ({ signal }) => backend.podcast(id, signal), enabled: !!user })
  const references = useQuery({ queryKey: ['moderation-references', user?.id, id], queryFn: ({ signal }) => backend.references(id, signal), enabled: !!detail.data })
  const history = useQuery({ queryKey: ['moderation-reviews', user?.id, id, historyPage], queryFn: ({ signal }) => backend.reviews(id, historyPage, 20, signal), enabled: !!detail.data })
  const getPreview = async () => { try { const value = await backend.preview(id); setPreview({ url: value.videoUrl, expiresAt: value.expiresAt }) } catch (error) { notify(errorMessage(error), 'error') } }
  const refresh = async () => { await Promise.all([client.invalidateQueries({ queryKey: ['moderation-podcasts', user?.id] }), client.invalidateQueries({ queryKey: ['dashboard', user?.id] }), detail.refetch(), references.refetch(), history.refetch()]) }
  if (detail.isPending) return <section className="panel mt-6"><LoadingState /></section>
  if (detail.isError || !detail.data) return <section className="panel mt-6"><ErrorState message={errorMessage(detail.error)} onRetry={() => { void detail.refetch() }} /></section>
  const podcast = detail.data.podcast
  return <section className="panel mt-6" tabIndex={-1} aria-label="Chi tiết podcast"><div className="panel-heading"><div><p className="eyebrow">Chi tiết podcast</p><h2 className="text-xl font-semibold">{podcast.title}</h2></div><Button variant="outline" onClick={onClose}>Đóng</Button></div><div className="p-6 space-y-6"><div className="grid gap-4 text-sm sm:grid-cols-2"><p><span className="text-muted-foreground">Trạng thái</span><br /><span className="badge">{podcastStatusLabels[podcast.status]}</span></p><p><span className="text-muted-foreground">Kênh Creator</span><br />{podcast.creatorChannelName || '—'}</p><p><span className="text-muted-foreground">Danh mục</span><br />{podcast.categoryName}</p><p><span className="text-muted-foreground">Gửi lúc</span><br />{date(podcast.submittedAt)}</p></div><p className="whitespace-pre-wrap text-sm leading-6">{podcast.description || 'Chưa có mô tả.'}</p><div className="flex flex-wrap gap-2"><Button variant="outline" onClick={() => { void getPreview() }}><Eye className="size-4" />{preview && !linkExpired(preview.expiresAt) ? 'Lấy lại preview' : 'Xem preview'}</Button>{preview && !linkExpired(preview.expiresAt) && <a className="inline-flex min-h-10 items-center gap-2 rounded-lg border border-border px-4 text-sm font-semibold text-primary" href={preview.url} target="_blank" rel="noopener noreferrer">Mở video<ExternalLink className="size-4" /></a>}</div>{preview && linkExpired(preview.expiresAt) && <p className="text-sm text-muted-foreground">Link preview đã hết hạn. Hãy lấy lại để tiếp tục.</p>}<div><h3 className="font-semibold">Nguồn tham khảo</h3>{references.isPending ? <LoadingState message="Đang tải nguồn…" /> : references.isError ? <ErrorState message={errorMessage(references.error)} onRetry={() => { void references.refetch() }} /> : references.data?.length ? <ul className="mt-3 space-y-3">{references.data.map(reference => <li key={reference.referenceId} className="rounded-lg border border-border p-3 text-sm"><p className="font-semibold">{reference.title}</p><p className="text-muted-foreground">{reference.author || 'Không rõ tác giả'} · {reference.referenceType}</p>{reference.url && <p className="mt-1 break-all text-xs text-muted-foreground">Nguồn: {reference.url}</p>}{reference.citationText && <p className="mt-1 whitespace-pre-wrap text-xs text-muted-foreground">{reference.citationText}</p>}{reference.fileKey ? <ReferenceDownload backend={backend} podcastId={id} referenceId={reference.referenceId} /> : <span className="text-xs text-muted-foreground">Chưa có PDF</span>}</li>)}</ul> : <EmptyState title="Chưa có nguồn tham khảo" message="Podcast không có tài liệu nguồn." />}</div><div><h3 className="font-semibold">Lịch sử kiểm duyệt</h3>{history.isPending ? <LoadingState message="Đang tải lịch sử kiểm duyệt…" /> : history.isError ? <ErrorState message={errorMessage(history.error)} onRetry={() => { void history.refetch() }} /> : history.data.content.length ? <><ul className="mt-3 space-y-2">{history.data.content.map(review => <li key={review.reviewId} className="rounded-lg bg-muted/40 p-3 text-sm"><b>{review.decision}</b> · {review.reviewerName || 'Nhân viên'} · {date(review.reviewedAt)}<p className="mt-1 whitespace-pre-wrap">{review.note || 'Không có ghi chú.'}</p></li>)}</ul><Pagination page={history.data} pending={history.isFetching} onPageChange={setHistoryPage} /></> : <EmptyState title="Chưa có lịch sử" message="Podcast chưa có quyết định kiểm duyệt." />}</div><div className="flex flex-wrap gap-2">{(['approve', 'reject', 'hide', 'restore', 'delete'] as PodcastAction[]).map(action => <PodcastAction key={action} podcastId={id} action={action} status={podcast.status} role={role} onDone={refresh} />)}</div></div></section>
}

function ReferenceDownload({ backend, podcastId, referenceId }: { backend: ReturnType<typeof createModerationApi>; podcastId: string; referenceId: string }) { const notify = useFeedback(); const [file, setFile] = useState<{ url: string; expiresAt: string } | null>(null); const load = async () => { try { const value = await backend.referenceFile(podcastId, referenceId); setFile({ url: value.downloadUrl, expiresAt: value.expiresAt }) } catch (error) { notify(errorMessage(error), 'error') } }; return file && !linkExpired(file.expiresAt) ? <a className="mt-2 inline-flex items-center gap-2 text-primary underline" href={file.url} target="_blank" rel="noopener noreferrer">Tải PDF<Download className="size-4" /></a> : <button className="mt-2 text-left text-sm font-semibold text-primary underline" onClick={() => { void load() }}>{file ? 'Lấy lại PDF' : 'Lấy link PDF'}</button> }

export function PodcastModerationPage() { const { user } = useAuth(); const role = user?.role; const backend = useMemo(() => createModerationApi(api, role === 'ADMIN' ? 'ADMIN' : 'STAFF'), [role]); const [filter, setFilter] = useState({ status: 'PENDING_REVIEW', page: 0 }); const [selected, setSelected] = useState<string | null>(null); const query = useQuery({ queryKey: key('moderation-podcasts', user?.id, filter.status, filter.page), enabled: !!user, queryFn: ({ signal }) => backend.podcasts(filter.status, filter.page, 20, signal) }); return <><Header title="Kiểm duyệt podcast" description="Xem, xem trước và xử lý podcast theo quyền được Backend cấp." refresh={() => { void query.refetch() }} loading={query.isFetching} /><section className="panel"><div className="panel-heading"><h2 className="font-semibold">Danh sách podcast</h2><select aria-label="Lọc trạng thái podcast" className="field w-auto" value={filter.status} onChange={event => { setFilter({ status: event.target.value, page: 0 }); setSelected(null) }}><option value="">Tất cả trạng thái</option>{Object.entries(podcastStatusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></div>{query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : query.data.content.length ? <><div className="overflow-x-auto"><table className="data-table"><thead><tr><th>Podcast</th><th>Kênh</th><th>Trạng thái</th><th>Ngày gửi</th><th /></tr></thead><tbody>{query.data.content.map(item => <Fragment key={item.podcastId}><tr><td><p className="font-semibold">{item.title}</p><p className="text-xs text-muted-foreground">{item.categoryName}</p></td><td>{item.creatorChannelName || '—'}</td><td><span className="badge">{podcastStatusLabels[item.status]}</span></td><td>{date(item.submittedAt)}</td><td><Button variant="outline" onClick={() => setSelected(item.podcastId)}>Chi tiết</Button></td></tr>{selected === item.podcastId && <tr><td colSpan={5} className="p-0"><PodcastDetail id={selected} role={role} onClose={() => setSelected(null)} /></td></tr>}</Fragment>)}</tbody></table></div><Pagination page={query.data} pending={query.isFetching} onPageChange={page => setFilter(current => ({ ...current, page }))} /></> : <EmptyState title="Không có podcast" message="Không có podcast phù hợp với bộ lọc." />}</section></> }

function Header({ title, description, refresh, loading }: { title: string; description: string; refresh: () => void; loading: boolean }) { return <div className="mb-7 flex flex-wrap items-end justify-between gap-4"><div><p className="eyebrow">Nội dung</p><h1 className="mt-2 text-3xl font-bold">{title}</h1><p className="mt-2 text-sm text-muted-foreground">{description}</p></div><Button variant="outline" disabled={loading} onClick={refresh}><RefreshCw className="size-4" />Làm mới</Button></div> }

function ReportDetail({ id, role, onClose }: { id: string; role: string | undefined; onClose: () => void }) {
  const { user } = useAuth()
  const notify = useFeedback()
  const client = useQueryClient()
  const backend = useMemo(() => createModerationApi(api, role === 'ADMIN' ? 'ADMIN' : 'STAFF'), [role])
  const initiatingModerator = useRef<{ id: string; role: Role } | null>(null)
  const report = useQuery({ queryKey: ['moderation-report', user?.id, id], queryFn: ({ signal }) => backend.report(id, signal), enabled: !!user })
  const podcast = useQuery({
    queryKey: ['moderation-report-podcast', user?.id, report.data?.targetId],
    queryFn: ({ signal }) => backend.podcast(report.data!.targetId, signal),
    enabled: !!report.data && isPodcastReportTarget(report.data),
  })
  const refresh = async (actorId = user?.id) => {
    const current = report.data
    const cacheKeys = current ? reportCacheKeys(actorId, current) : reportCacheKeys(actorId, { targetType: 'COMMENT', targetId: '' })
    const tasks: Promise<unknown>[] = [
      client.invalidateQueries({ queryKey: cacheKeys.reports }),
      client.invalidateQueries({ queryKey: cacheKeys.dashboard }),
      report.refetch(),
    ]
    if (current && isPodcastReportTarget(current)) {
      for (const queryKey of cacheKeys.podcasts) tasks.push(client.invalidateQueries({ queryKey }))
      tasks.push(podcast.refetch())
    }
    await Promise.all(tasks)
  }
  const claim = useMutation({
    mutationFn: () => { const expected = initiatingModerator.current; if (!expected) throw new Error(sessionChangedMessage); requireCurrentModerator(expected); return backend.claimReport(id) },
    onSuccess: async () => {
      const expected = initiatingModerator.current
      if (!expected) return
      requireCurrentModerator(expected)
      await refresh(expected.id)
      requireCurrentModerator(expected)
      notify(report.data?.assigneeId ? moderationSuccessMessages.reclaim : moderationSuccessMessages.claim)
    },
    onError: async error => {
      notify(errorMessage(error), 'error')
      const expected = initiatingModerator.current
      if (extractApiError(error).outcomeUnknown && expected && sameModerator(session.getUser(), expected)) {
        try { await refresh(expected.id) } catch { /* The warning already asks the user to verify current state. */ }
      }
    },
  })
  const resolve = useMutation({
    mutationFn: ({ action, note }: { action: ReportAction; note: string }) => { const expected = initiatingModerator.current; if (!expected) throw new Error(sessionChangedMessage); requireCurrentModerator(expected); return backend.resolveReport(id, action, note) },
    onSuccess: async (_data, variables) => { const expected = initiatingModerator.current; if (!expected) return; requireCurrentModerator(expected); await refresh(expected.id); requireCurrentModerator(expected); notify(moderationSuccessMessages[variables.action]) },
    onError: async error => { const expected = initiatingModerator.current; if (extractApiError(error).outcomeUnknown && expected && sameModerator(session.getUser(), expected)) { try { await refresh(expected.id) } catch { /* The warning already asks the user to verify current state. */ } } },
  })
  if (report.isPending) return <section className="panel mt-6"><LoadingState /></section>
  if (report.isError || !report.data) return <section className="panel mt-6"><ErrorState message={errorMessage(report.error)} onRetry={() => { void report.refetch() }} /></section>
  const data = report.data
  const actions = reportActions(role, user?.id, data, podcast.data?.podcast)
  return <section className="panel mt-6"><div className="panel-heading"><div><p className="eyebrow">Chi tiết báo cáo</p><h2 className="text-xl font-semibold">{targetLabels[data.targetType]} · {data.reasonCode || 'Không rõ lý do'}</h2></div><Button variant="outline" onClick={onClose}>Đóng</Button></div><div className="p-6 space-y-5 text-sm"><div className="grid gap-4 sm:grid-cols-2"><p>Người báo cáo<br /><b>{data.reporterName || data.reporterId}</b></p><p>Đối tượng<br /><span className="break-all font-mono text-xs">{data.targetId}</span></p><p>Trạng thái<br /><span className="badge">{reportStatusLabels[data.status]}</span></p><p>Người xử lý<br />{data.assigneeId || 'Chưa có'}</p><p>Tạo lúc<br />{date(data.createdAt)}</p><p>Kết thúc lúc<br />{date(data.resolvedAt)}</p></div><p className="whitespace-pre-wrap">{data.description || 'Không có mô tả.'}</p>{data.targetType === 'PODCAST' && podcast.isPending && <LoadingState message="Đang kiểm tra trạng thái podcast…" />}{data.targetType === 'PODCAST' && podcast.data && <p>Podcast: <b>{podcast.data.podcast.title}</b> · {podcast.data.podcast.status}</p>}<div className="flex flex-wrap gap-2"><Button variant="outline" disabled={!canHandleReport(role, user?.id, data) || claim.isPending} onClick={() => { initiatingModerator.current = currentModerator(); void claim.mutate() }}>{claim.isPending ? 'Đang nhận…' : data.assigneeId ? 'Nhận lại báo cáo' : 'Nhận xử lý'}</Button>{actions.map(action => <NoteDialog key={action} fieldId={`report-${id}-${action.toLowerCase()}-note`} schema={moderationNoteSchema} title={`${reportActionLabels[action]}?`} description="Ghi chú sẽ được lưu cùng quyết định xử lý." confirmLabel="Xác nhận" destructive={action !== 'DISMISS'} onOpenChange={open => { initiatingModerator.current = open ? currentModerator() : null }} onConfirm={async note => { await resolve.mutateAsync({ action, note }) }}><Button variant="outline" disabled={resolve.isPending}>{reportActionLabels[action]}</Button></NoteDialog>)}</div><div><h3 className="font-semibold">Lịch sử xử lý</h3>{data.reviews.length ? <ul className="mt-3 space-y-2">{data.reviews.map(item => <li key={item.reviewId} className="rounded-lg bg-muted/40 p-3">{item.decision} · {item.reviewerName || item.reviewerId} · {date(item.reviewedAt)}<p>{item.note || '—'}</p></li>)}</ul> : <p className="mt-2 text-muted-foreground">Chưa có lịch sử.</p>}</div></div></section>
}

export function ReportsPage() { const { user } = useAuth(); const role = user?.role; const backend = useMemo(() => createModerationApi(api, role === 'ADMIN' ? 'ADMIN' : 'STAFF'), [role]); const [filter, setFilter] = useState({ status: 'PENDING', page: 0 }); const [selected, setSelected] = useState<string | null>(null); const query = useQuery({ queryKey: key('moderation-reports', user?.id, filter.status, filter.page), enabled: !!user, queryFn: ({ signal }) => backend.reports(filter.status, filter.page, 20, signal) }); return <><Header title="Báo cáo vi phạm" description="Theo dõi, nhận xử lý và giải quyết báo cáo theo phân quyền." refresh={() => { void query.refetch() }} loading={query.isFetching} /><section className="panel"><div className="panel-heading"><h2 className="font-semibold">Danh sách báo cáo</h2><select aria-label="Lọc trạng thái báo cáo" className="field w-auto" value={filter.status} onChange={event => { setFilter({ status: event.target.value, page: 0 }); setSelected(null) }}><option value="">Tất cả trạng thái</option>{Object.entries(reportStatusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></div>{query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : query.data.content.length ? <><div className="overflow-x-auto"><table className="data-table"><thead><tr><th>Đối tượng</th><th>Lý do</th><th>Trạng thái</th><th>Người xử lý</th><th /></tr></thead><tbody>{query.data.content.map(item => <Fragment key={item.reportId}><tr><td>{targetLabels[item.targetType]}<p className="font-mono text-xs text-muted-foreground">{item.targetId}</p></td><td>{item.reasonCode || '—'}</td><td><span className="badge">{reportStatusLabels[item.status]}</span></td><td>{item.assigneeId || 'Chưa có'}</td><td><Button variant="outline" onClick={() => setSelected(item.reportId)}>Chi tiết</Button></td></tr>{selected === item.reportId && <tr><td colSpan={5} className="p-0"><ReportDetail id={selected} role={role} onClose={() => setSelected(null)} /></td></tr>}</Fragment>)}</tbody></table></div><Pagination page={query.data} pending={query.isFetching} onPageChange={page => setFilter(current => ({ ...current, page }))} /></> : <EmptyState title="Không có báo cáo" message="Không có báo cáo phù hợp với bộ lọc." />}</section></> }

function AppealDetail({ id, role, onClose }: { id: string; role: string | undefined; onClose: () => void }) {
  const { user } = useAuth()
  const notify = useFeedback()
  const client = useQueryClient()
  const backend = useMemo(() => createModerationApi(api, role === 'ADMIN' ? 'ADMIN' : 'STAFF'), [role])
  const initiatingModerator = useRef<{ id: string; role: Role } | null>(null)
  const appeal = useQuery({ queryKey: ['moderation-appeal', user?.id, id], queryFn: ({ signal }) => backend.appeal(id, signal), enabled: !!user })
  const podcast = useQuery({ queryKey: ['moderation-appeal-podcast', user?.id, appeal.data?.podcastId], queryFn: ({ signal }) => backend.podcast(appeal.data!.podcastId, signal), enabled: !!appeal.data })
  const refresh = async (actorId = user?.id) => {
    const current = appeal.data
    const cacheKeys = appealCacheKeys(actorId, current?.podcastId)
    const tasks: Promise<unknown>[] = [client.invalidateQueries({ queryKey: cacheKeys.appeals }), client.invalidateQueries({ queryKey: cacheKeys.dashboard }), appeal.refetch()]
    if (current && cacheKeys.podcast) tasks.push(client.invalidateQueries({ queryKey: cacheKeys.podcasts }), client.invalidateQueries({ queryKey: cacheKeys.podcast }), podcast.refetch())
    await Promise.all(tasks)
  }
  const resolve = useMutation({
    mutationFn: ({ decision, note }: { decision: AppealDecision; note: string }) => { const expected = initiatingModerator.current; if (!expected) throw new Error(sessionChangedMessage); requireCurrentModerator(expected); return backend.resolveAppeal(id, decision, note) },
    onSuccess: async (_data, variables) => { const expected = initiatingModerator.current; if (!expected) return; requireCurrentModerator(expected); await refresh(expected.id); requireCurrentModerator(expected); notify(moderationSuccessMessages[variables.decision]) },
    onError: async error => { const expected = initiatingModerator.current; if (extractApiError(error).outcomeUnknown && expected && sameModerator(session.getUser(), expected)) { try { await refresh(expected.id) } catch { /* The warning already asks the user to verify current state. */ } } },
  })
  if (appeal.isPending) return <section className="panel mt-6"><LoadingState /></section>
  if (appeal.isError || !appeal.data) return <section className="panel mt-6"><ErrorState message={errorMessage(appeal.error)} onRetry={() => { void appeal.refetch() }} /></section>
  const data = appeal.data
  return <section className="panel mt-6"><div className="panel-heading"><div><p className="eyebrow">Chi tiết khiếu nại</p><h2 className="text-xl font-semibold">{podcast.data?.podcast.title || data.podcastId}</h2></div><Button variant="outline" onClick={onClose}>Đóng</Button></div><div className="p-6 space-y-5 text-sm"><div className="grid gap-4 sm:grid-cols-2"><p>Creator<br /><b>{podcast.data?.podcast.creatorChannelName || data.applicantId}</b></p><p>Trạng thái<br /><span className="badge">{appealStatusLabels[data.status]}</span></p><p>Tạo lúc<br />{date(data.createdAt)}</p><p>Giải quyết lúc<br />{date(data.resolvedAt)}</p></div><p className="whitespace-pre-wrap"><b>Lý do:</b> {data.reason}</p>{podcast.isError && <ErrorState message={errorMessage(podcast.error)} onRetry={() => { void podcast.refetch() }} />}<div className="flex flex-wrap gap-2"><NoteDialog fieldId={`appeal-${id}-accept-note`} schema={moderationNoteSchema} title="Chấp nhận khiếu nại?" description="Podcast đủ điều kiện sẽ quay về PENDING_REVIEW, không được xuất bản trực tiếp." confirmLabel="Chấp nhận" onOpenChange={open => { initiatingModerator.current = open ? currentModerator() : null }} onConfirm={async note => { await resolve.mutateAsync({ decision: 'ACCEPT', note }) }}><Button disabled={!canResolveAppeal(role, data, 'ACCEPT', podcast.data?.podcast) || resolve.isPending}>Chấp nhận</Button></NoteDialog><NoteDialog fieldId={`appeal-${id}-reject-note`} schema={moderationNoteSchema} title="Từ chối khiếu nại?" description="Trạng thái podcast sẽ được giữ nguyên." confirmLabel="Từ chối" destructive onOpenChange={open => { initiatingModerator.current = open ? currentModerator() : null }} onConfirm={async note => { await resolve.mutateAsync({ decision: 'REJECT', note }) }}><Button variant="outline" disabled={!canResolveAppeal(role, data, 'REJECT', podcast.data?.podcast) || resolve.isPending}>Từ chối</Button></NoteDialog></div></div></section>
}

export function AppealsPage() { const { user } = useAuth(); const role = user?.role; const backend = useMemo(() => createModerationApi(api, role === 'ADMIN' ? 'ADMIN' : 'STAFF'), [role]); const [filter, setFilter] = useState({ status: 'PENDING', page: 0 }); const [selected, setSelected] = useState<string | null>(null); const query = useQuery({ queryKey: key('moderation-appeals', user?.id, filter.status, filter.page), enabled: !!user, queryFn: ({ signal }) => backend.appeals(filter.status, filter.page, 20, signal) }); return <><Header title="Khiếu nại podcast" description="Xem lý do và quyết định khiếu nại theo trạng thái hiện tại." refresh={() => { void query.refetch() }} loading={query.isFetching} /><section className="panel"><div className="panel-heading"><h2 className="font-semibold">Danh sách khiếu nại</h2><select aria-label="Lọc trạng thái khiếu nại" className="field w-auto" value={filter.status} onChange={event => { setFilter({ status: event.target.value, page: 0 }); setSelected(null) }}><option value="">Tất cả trạng thái</option>{Object.entries(appealStatusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></div>{query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : query.data.content.length ? <><div className="overflow-x-auto"><table className="data-table"><thead><tr><th>Podcast</th><th>Người gửi</th><th>Trạng thái</th><th>Ngày gửi</th><th /></tr></thead><tbody>{query.data.content.map(item => <Fragment key={item.appealId}><tr><td className="font-mono text-xs">{item.podcastId}</td><td className="font-mono text-xs">{item.applicantId}</td><td><span className="badge">{appealStatusLabels[item.status]}</span></td><td>{date(item.createdAt)}</td><td><Button variant="outline" onClick={() => setSelected(item.appealId)}>Chi tiết</Button></td></tr>{selected === item.appealId && <tr><td colSpan={5} className="p-0"><AppealDetail id={selected} role={role} onClose={() => setSelected(null)} /></td></tr>}</Fragment>)}</tbody></table></div><Pagination page={query.data} pending={query.isFetching} onPageChange={page => setFilter(current => ({ ...current, page }))} /></> : <EmptyState title="Không có khiếu nại" message="Không có khiếu nại phù hợp với bộ lọc." />}</section></> }
