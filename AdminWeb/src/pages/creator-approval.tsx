import { useEffect, useRef, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { Check, ExternalLink, RefreshCw, X } from 'lucide-react'
import { useAuth } from '../auth'
import { api, errorMessage, session } from '../lib/client'
import { createAdminApi } from '../lib/admin-api'
import { adminKeys, creatorReviewConfirmed } from '../lib/admin-cache'
import { extractApiError } from '../lib/api-error'
import { successMessages } from '../lib/success-feedback'
import { approveCreatorSchema, rejectCreatorSchema, canReviewApplication, safePortfolioUrl } from '../lib/admin-contracts'
import type { CreatorApplication, CreatorStatus } from '../lib/admin-contracts'
import { Button } from '../components/ui/button'
import { ConfirmDialog } from '../components/ui/confirm-dialog'
import { Pagination } from '../components/pagination'
import { EmptyState, ErrorState, LoadingState } from '../components/states'
import { useFeedback } from '../components/feedback'

const backend = createAdminApi(api)
const statuses: Record<CreatorStatus, string> = { PENDING: 'Chờ duyệt', APPROVED: 'Đã duyệt', REJECTED: 'Đã từ chối' }
const date = (value: string | null) => value ? new Date(value).toLocaleString('vi-VN') : '—'

function CreatorDecision({ application, decision }: { application: CreatorApplication; decision: 'approve' | 'reject' }) {
  const { user } = useAuth()
  const client = useQueryClient()
  const notify = useFeedback()
  const rejection = decision === 'reject'
  const form = useForm({ resolver: zodResolver(rejection ? rejectCreatorSchema : approveCreatorSchema), defaultValues: { note: '' }, mode: 'onChange' })
  const mutation = useMutation({
    mutationFn: (values: { note: string }) => backend.review(application.applicationId, decision, values),
    onSuccess: async data => {
      if (session.getUser()?.id !== user?.id || session.getUser()?.role !== 'ADMIN') return
      await creatorReviewConfirmed(client, user?.id, data)
      if (session.getUser()?.id !== user?.id || session.getUser()?.role !== 'ADMIN') return
      notify(rejection ? successMessages.creatorRejected : successMessages.creatorApproved)
    },
    onError: async error => {
      if (!extractApiError(error).outcomeUnknown || session.getUser()?.id !== user?.id || session.getUser()?.role !== 'ADMIN') return
      notify(errorMessage(error), 'error')
      await Promise.all([client.invalidateQueries({ queryKey: adminKeys.creators(user?.id) }), client.invalidateQueries({ queryKey: ['dashboard', user?.id] })])
    },
  })
  const noteId = `${decision}-note`
  return <ConfirmDialog
    trigger={<Button variant={rejection ? 'outline' : 'default'} disabled={!canReviewApplication(user?.role, application.status) || mutation.isPending}>{rejection ? <X className="size-4" /> : <Check className="size-4" />}{rejection ? 'Từ chối' : 'Duyệt hồ sơ'}</Button>}
    title={rejection ? 'Từ chối hồ sơ Creator?' : 'Duyệt hồ sơ Creator?'}
    description={rejection ? `Hồ sơ của ${application.username} sẽ được từ chối. Hãy ghi rõ lý do để người đăng ký biết cần bổ sung gì.` : `Backend sẽ chuyển tài khoản ${application.username} sang vai trò CREATOR. Xác nhận sau khi đã kiểm tra hồ sơ.`}
    confirmLabel={rejection ? 'Xác nhận từ chối' : 'Xác nhận duyệt'} destructive={rejection}
    confirmDisabled={rejection && !form.formState.isValid}
    onOpenChange={() => { form.reset({ note: '' }); mutation.reset() }}
    onConfirm={async () => {
      if (!await form.trigger()) throw new Error('Kiểm tra ghi chú trước khi xác nhận.')
      await mutation.mutateAsync(form.getValues())
    }}>
    <label htmlFor={noteId} className="field-label">{rejection ? 'Lý do từ chối *' : 'Ghi chú (không bắt buộc)'}</label>
    <textarea id={noteId} rows={5} maxLength={2000} className="field py-3" aria-invalid={!!form.formState.errors.note} aria-describedby={`${noteId}-help ${noteId}-error`} {...form.register('note')} />
    <p id={`${noteId}-help`} className="mt-2 text-xs text-muted-foreground">Tối đa 2.000 ký tự.</p>
    {form.formState.errors.note && <p id={`${noteId}-error`} className="field-error">{form.formState.errors.note.message}</p>}
  </ConfirmDialog>
}

function CreatorDetail({ applicationId, onClose }: { applicationId: string; onClose: () => void }) {
  const section = useRef<HTMLElement>(null)
  useEffect(() => {
    section.current?.scrollIntoView({ block: 'start' })
    section.current?.focus({ preventScroll: true })
  }, [])
  const { user } = useAuth()
  const query = useQuery({ queryKey: adminKeys.creatorDetail(user?.id, applicationId), enabled: user?.role === 'ADMIN', queryFn: ({ signal }) => backend.application(applicationId, signal) })
  const data = query.data
  const portfolio = data ? safePortfolioUrl(data.portfolioUrl) : undefined
  return <section ref={section} tabIndex={-1} className="panel mt-6 scroll-mt-24" aria-label="Chi tiết hồ sơ Creator">
    <div className="panel-heading"><h2 className="text-lg font-semibold">Chi tiết hồ sơ</h2><div className="flex gap-2"><Button variant="outline" disabled={query.isFetching} onClick={() => { void query.refetch() }}>Làm mới</Button><Button variant="ghost" aria-label="Đóng chi tiết hồ sơ" onClick={onClose}><X className="size-5" /></Button></div></div>
    {query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : data && <div className="p-6">
      <div className="flex flex-wrap items-center justify-between gap-4"><div><h3 className="text-xl font-semibold">{data.channelName || 'Chưa đặt tên kênh'}</h3><p className="mt-2 break-all text-sm text-muted-foreground">{data.username} · {data.email}</p></div><span className={`badge ${data.status === 'APPROVED' ? 'bg-success/10 text-success' : data.status === 'REJECTED' ? 'bg-destructive/10 text-destructive' : ''}`}>{statuses[data.status]}</span></div>
      <dl className="mt-6 grid gap-5 text-sm sm:grid-cols-2">
        <div><dt className="text-muted-foreground">ID hồ sơ / Creator profile</dt><dd className="mt-1 break-all font-mono text-xs">{data.applicationId}</dd></div>
        <div><dt className="text-muted-foreground">ID người đăng ký</dt><dd className="mt-1 break-all font-mono text-xs">{data.applicantUserId}</dd></div>
        <div><dt className="text-muted-foreground">Gửi lúc</dt><dd className="mt-1">{date(data.submittedAt)}</dd></div>
        <div><dt className="text-muted-foreground">Xử lý lúc</dt><dd className="mt-1">{date(data.reviewedAt)}</dd></div>
        <div className="sm:col-span-2"><dt className="text-muted-foreground">Giới thiệu</dt><dd className="mt-2 whitespace-pre-wrap break-words leading-6">{data.introduction || 'Chưa có giới thiệu.'}</dd></div>
        <div className="sm:col-span-2"><dt className="text-muted-foreground">Portfolio</dt><dd className="mt-2 break-all">{portfolio ? <a href={portfolio} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-2 text-primary underline">{data.portfolioUrl}<ExternalLink className="size-4 shrink-0" /></a> : data.portfolioUrl || 'Chưa có portfolio.'}</dd></div>
        <div className="sm:col-span-2"><dt className="text-muted-foreground">Ghi chú xét duyệt</dt><dd className="mt-2 whitespace-pre-wrap break-words">{data.reviewNote || 'Chưa có ghi chú.'}</dd></div>
      </dl>
      {data.status === 'PENDING' && user?.role === 'ADMIN' ? <div className="mt-7 flex flex-wrap gap-3"><CreatorDecision key={`${applicationId}-approve`} application={data} decision="approve" /><CreatorDecision key={`${applicationId}-reject`} application={data} decision="reject" /></div> : <p className="mt-6 text-sm text-muted-foreground">Hồ sơ đã được xử lý; không thể duyệt hoặc từ chối lại.</p>}
    </div>}
  </section>
}

export function CreatorApprovalPage() {
  const { user } = useAuth()
  const [filter, setFilter] = useState<{ status: CreatorStatus | ''; page: number }>({ status: 'PENDING', page: 0 })
  const [selected, setSelected] = useState<string | null>(null)
  const query = useQuery({ queryKey: adminKeys.creatorList(user?.id, filter.status, filter.page, 20), enabled: user?.role === 'ADMIN', queryFn: ({ signal }) => backend.applications(filter.status, filter.page, 20, signal) })
  // A decision can remove the last PENDING item on the last page.
  useEffect(() => {
    const data = query.data
    if (data && data.number > 0 && data.number >= data.totalPages) {
      setFilter(current => current.page === data.number ? { ...current, page: Math.max(0, data.totalPages - 1) } : current)
    }
  }, [query.data])
  return <>
    <div className="mb-7 flex flex-wrap items-end justify-between gap-4"><div><p className="eyebrow">Quản lý Creator</p><h1 className="mt-2 text-3xl font-bold">Duyệt hồ sơ Creator</h1><p className="mt-2 text-sm text-muted-foreground">Xem hồ sơ đăng ký và theo dõi kết quả xét duyệt.</p></div><Button variant="outline" disabled={query.isFetching} onClick={() => { void query.refetch() }}><RefreshCw className="size-4" />Làm mới</Button></div>
    <section className="panel"><div className="panel-heading"><h2 className="font-semibold">Danh sách hồ sơ</h2><div className="flex items-center gap-3"><label htmlFor="creator-status" className="text-sm">Trạng thái</label><select id="creator-status" className="field w-auto" value={filter.status} onChange={event => { setFilter({ status: event.target.value as CreatorStatus | '', page: 0 }); setSelected(null) }}><option value="">Tất cả</option>{Object.entries(statuses).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></div></div>
      {query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : query.data && <>
        {query.data.content.length ? <div className="overflow-x-auto"><table className="data-table"><thead><tr><th>Người đăng ký</th><th>Kênh</th><th>Trạng thái</th><th>Ngày gửi</th><th><span className="sr-only">Thao tác</span></th></tr></thead><tbody>{query.data.content.map(item => <tr key={item.applicationId} className={selected === item.applicationId ? 'bg-primary/5' : ''}><td><p className="font-semibold">{item.username}</p><p className="mt-1 text-xs text-muted-foreground">{item.email}</p></td><td>{item.channelName || '—'}</td><td><span className="badge">{statuses[item.status]}</span></td><td className="whitespace-nowrap">{date(item.submittedAt)}</td><td><Button variant="outline" aria-expanded={selected === item.applicationId} aria-label={`Xem hồ sơ ${item.username}`} onClick={() => setSelected(item.applicationId)}>Chi tiết</Button></td></tr>)}</tbody></table></div> : <EmptyState title="Không có hồ sơ phù hợp" message="Đổi bộ lọc hoặc tải lại để kiểm tra hồ sơ mới." />}
        <Pagination page={query.data} pending={query.isFetching} onPageChange={page => setFilter(current => ({ ...current, page }))} />
      </>}
    </section>
    {selected && <CreatorDetail key={selected} applicationId={selected} onClose={() => setSelected(null)} />}
  </>
}
