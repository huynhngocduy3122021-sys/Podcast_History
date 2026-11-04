import { Fragment, useRef, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Eye, ExternalLink, RefreshCw } from 'lucide-react'
import { useAuth } from '../auth'
import { api, errorMessage, session } from '../lib/client'
import { extractApiError } from '../lib/api-error'
import { createAdminApi } from '../lib/admin-api'
import { adminKeys } from '../lib/admin-cache'
import { canAccess } from '../lib/permissions'
import { resolveMilestoneDisputeSchema } from '../lib/admin-contracts'
import type { MilestoneDispute, ResolveMilestoneDispute } from '../lib/admin-contracts'
import { identityOf, sameIdentity } from '../lib/identity'
import { formatDate, statusClass } from '../lib/finance-format'
import { Button } from '../components/ui/button'
import { ConfirmDialog } from '../components/ui/confirm-dialog'
import { EmptyState, ErrorState, LoadingState } from '../components/states'
import { useFeedback } from '../components/feedback'

const backend = createAdminApi(api)
const decisions = [
  { value: 'APPROVE_MILESTONE', label: 'Duyệt milestone' },
  { value: 'REQUEST_REVISION', label: 'Yêu cầu chỉnh sửa' },
  { value: 'LISTENER_WINS', label: 'Listener thắng' },
  { value: 'CREATOR_WINS', label: 'Creator thắng' },
] as const
const pageKey = (userId: string | undefined, status: string) => adminKeys.milestoneDisputeList(userId, status)
const sessionChangedMessage = 'Phiên đăng nhập đã thay đổi. Vui lòng tải lại dữ liệu trước khi tiếp tục.'

function ResolveAction({ dispute, onDone }: { dispute: MilestoneDispute; onDone: () => void }) {
  const client = useQueryClient()
  const notify = useFeedback()
  const initiatingIdentity = useRef<ReturnType<typeof identityOf>>(null)
  const confirmed = Boolean(dispute.opponentConfirmedAt)
  const available = decisions.filter(item => confirmed ? item.value === 'LISTENER_WINS' || item.value === 'CREATOR_WINS' : item.value === 'APPROVE_MILESTONE' || item.value === 'REQUEST_REVISION')
  const [decision, setDecision] = useState<ResolveMilestoneDispute['decision']>(confirmed ? 'LISTENER_WINS' : 'APPROVE_MILESTONE')
  const [note, setNote] = useState('')
  const mutation = useMutation({
    retry: false,
    mutationFn: () => {
      const expected = initiatingIdentity.current
      if (!expected || !canAccess(expected.role) || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      return backend.resolveMilestoneDispute(dispute.disputeId, { decision, note })
    },
    onSuccess: async data => {
      const expected = initiatingIdentity.current
      if (!expected || !canAccess(expected.role) || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      await client.invalidateQueries({ queryKey: pageKey(expected.id, dispute.status) })
      await client.invalidateQueries({ queryKey: ['admin-milestone-disputes', expected.id] })
      if (!sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      notify(`Đã kết luận tranh chấp milestone: ${data.decision}.`)
      onDone()
    },
    onError: async error => {
      const expected = initiatingIdentity.current
      if (extractApiError(error).outcomeUnknown && expected && sameIdentity(expected, identityOf(session.getUser()))) await client.invalidateQueries({ queryKey: ['milestone-disputes', expected.id] })
    },
  })
  const parsed = resolveMilestoneDisputeSchema.safeParse({ decision, note })
  return <ConfirmDialog trigger={<Button disabled={mutation.isPending}>Kết luận</Button>} title="Kết luận tranh chấp milestone" description={confirmed ? 'Tranh chấp đã được xác nhận; chọn bên thắng để Backend xử lý escrow.' : 'Backend sẽ kiểm tra lại trạng thái milestone trước khi ghi nhận quyết định.'} confirmLabel="Xác nhận" confirmDisabled={!parsed.success || mutation.isPending} onOpenChange={open => { initiatingIdentity.current = open ? identityOf(session.getUser()) : null; if (open) { setDecision(confirmed ? 'LISTENER_WINS' : 'APPROVE_MILESTONE'); setNote(''); mutation.reset() } }} onConfirm={async () => { await mutation.mutateAsync() }}>
    <div className="space-y-4"><div><label className="field-label" htmlFor={`milestone-decision-${dispute.disputeId}`}>Quyết định *</label><select id={`milestone-decision-${dispute.disputeId}`} className="field mt-2" value={decision} onChange={event => setDecision(resolveMilestoneDisputeSchema.shape.decision.parse(event.target.value))}>{available.map(item => <option key={item.value} value={item.value}>{item.label}</option>)}</select></div><div><label className="field-label" htmlFor={`milestone-note-${dispute.disputeId}`}>Ghi chú *</label><textarea id={`milestone-note-${dispute.disputeId}`} className="field mt-2 py-3" rows={4} maxLength={5000} value={note} onChange={event => setNote(event.target.value)} /></div></div>
  </ConfirmDialog>
}

function DisputeDetail({ dispute, onClose, onDone }: { dispute: MilestoneDispute; onClose: () => void; onDone: () => void }) {
  const { user } = useAuth()
  const submissions = useQuery({ queryKey: adminKeys.milestoneSubmissions(user?.id, dispute.milestoneId), enabled: canAccess(user?.role), queryFn: ({ signal }) => backend.milestoneDisputeSubmissions(dispute.milestoneId, signal) })
  const [mediaUrl, setMediaUrl] = useState<Record<string, string>>({})
  const loadMedia = async (submissionId: string) => {
    try { const media = await backend.milestoneSubmissionMedia(dispute.milestoneId, submissionId); setMediaUrl(current => ({ ...current, [submissionId]: media.url })) } catch { /* Error is shown by the next refresh/action. */ }
  }
  return <section className="panel mt-4"><div className="panel-heading"><div><p className="eyebrow">Chi tiết milestone dispute</p><h3 className="text-lg font-semibold">{dispute.disputeId}</h3></div><Button variant="ghost" onClick={onClose}>Đóng</Button></div><div className="space-y-5 p-6 text-sm"><div className="grid gap-4 sm:grid-cols-2"><p>Milestone<br /><span className="break-all font-mono text-xs">{dispute.milestoneId}</span></p><p>Người mở<br /><span className="break-all font-mono text-xs">{dispute.raisedByUserId}</span></p><p>Trạng thái<br /><span className={`badge ${statusClass(dispute.status)}`}>{dispute.status}</span></p><p>Deadline<br />{formatDate(dispute.responseDeadlineAt)}</p><p>Đã xác nhận lúc<br />{formatDate(dispute.opponentConfirmedAt)}</p><p>Tạo lúc<br />{formatDate(dispute.createdAt)}</p></div><div className="rounded-lg border border-border/70 p-4"><p className="text-xs text-muted-foreground">Lý do</p><p className="mt-2 whitespace-pre-wrap">{dispute.reason}</p></div><div><h4 className="font-semibold">Lịch sử bàn giao</h4>{submissions.isPending ? <LoadingState /> : submissions.isError ? <ErrorState message={errorMessage(submissions.error)} onRetry={() => { void submissions.refetch() }} /> : submissions.data.length ? <ul className="mt-3 space-y-2">{submissions.data.map(item => <li key={item.submissionId} className="flex flex-wrap items-center justify-between gap-3 rounded-lg bg-muted/40 p-3"><div><p className="font-medium">Revision {item.revisionNumber}</p><p className="text-xs text-muted-foreground">{formatDate(item.submittedAt)} · {item.contentType || 'Không rõ loại file'}</p><p className="mt-1 text-xs">{item.note || 'Không có ghi chú.'}</p></div>{mediaUrl[item.submissionId] ? <a className="inline-flex items-center gap-2 text-primary underline" href={mediaUrl[item.submissionId]} target="_blank" rel="noopener noreferrer">Mở media <ExternalLink className="size-4" /></a> : <Button variant="outline" onClick={() => { void loadMedia(item.submissionId) }}>Lấy link media</Button>}</li>)}</ul> : <EmptyState title="Chưa có bàn giao" message="Chưa có submission để Staff/Admin xem xét." />}</div>{dispute.status === 'OPEN' && <ResolveAction dispute={dispute} onDone={onDone} />}</div></section>
}

export function MilestoneDisputesPage() {
  const { user } = useAuth()
  const [status, setStatus] = useState('OPEN')
  const [selected, setSelected] = useState<string | null>(null)
  const query = useQuery({ queryKey: pageKey(user?.id, status), enabled: canAccess(user?.role), queryFn: ({ signal }) => backend.milestoneDisputes(status, signal) })
  const data = query.data || []
  return <><div className="mb-7 flex flex-wrap items-end justify-between gap-4"><div><p className="eyebrow">Tài chính & hợp đồng</p><h1 className="mt-2 text-3xl font-bold">Milestone disputes</h1><p className="mt-2 text-sm text-muted-foreground">Staff/Admin xem chứng cứ và kết luận tranh chấp từng milestone.</p></div><Button variant="outline" disabled={query.isFetching} onClick={() => { void query.refetch() }}><RefreshCw className="size-4" />Làm mới</Button></div><section className="panel"><div className="panel-heading"><h2 className="font-semibold">Danh sách tranh chấp</h2><select aria-label="Lọc trạng thái milestone dispute" className="field w-auto" value={status} onChange={event => { setStatus(event.target.value); setSelected(null) }}><option value="OPEN">OPEN</option><option value="AWAITING_RESPONSE">AWAITING_RESPONSE</option><option value="RESOLVED">RESOLVED</option></select></div>{query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : data.length ? <ul className="divide-y divide-border/60">{data.map(dispute => <Fragment key={dispute.disputeId}><li className="flex flex-wrap items-center justify-between gap-4 p-5"><div className="min-w-0"><p className="font-semibold">{dispute.disputeId}</p><p className="mt-1 break-all font-mono text-xs text-muted-foreground">Milestone: {dispute.milestoneId}</p><p className="mt-1 truncate text-sm">{dispute.reason}</p></div><div className="flex items-center gap-2"><span className={`badge ${statusClass(dispute.status)}`}>{dispute.status}</span><Button variant="outline" onClick={() => setSelected(selected === dispute.disputeId ? null : dispute.disputeId)}><Eye className="size-4" />Chi tiết</Button></div></li>{selected === dispute.disputeId && <li className="p-5"><DisputeDetail dispute={dispute} onClose={() => setSelected(null)} onDone={() => { setSelected(null); void query.refetch() }} /></li>}</Fragment>)}</ul> : <EmptyState title="Không có tranh chấp" message="Không có milestone dispute phù hợp với trạng thái hiện tại." />}</section></>
}
