import { Fragment, useRef, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Eye, RefreshCw, RotateCcw, ShieldCheck } from 'lucide-react'
import { useAuth } from '../auth'
import { api, errorMessage, session } from '../lib/client'
import { extractApiError } from '../lib/api-error'
import { createAdminApi } from '../lib/admin-api'
import { adminKeys, paymentChangeConfirmed } from '../lib/admin-cache'
import { paymentReconcileSchema, paymentRefundSchema } from '../lib/admin-contracts'
import type { Payment, PaymentReconcile, PaymentStatus } from '../lib/admin-contracts'
import { identityOf, sameIdentity } from '../lib/identity'
import { formatMoney } from '../lib/finance-format'
import { Button } from '../components/ui/button'
import { ConfirmDialog } from '../components/ui/confirm-dialog'
import { EmptyState, ErrorState, LoadingState } from '../components/states'
import { useFeedback } from '../components/feedback'

const backend = createAdminApi(api)
const pageSize = 20
const sessionChangedMessage = 'Phiên đăng nhập đã thay đổi. Vui lòng tải lại dữ liệu trước khi tiếp tục.'
const statusOptions: Array<{ value: PaymentStatus | ''; label: string }> = [
  { value: '', label: 'Mọi trạng thái' },
  { value: 'PENDING', label: 'PENDING · Chờ đối soát' },
  { value: 'PAID', label: 'PAID · Đã thu' },
  { value: 'SUCCESS', label: 'SUCCESS · Đã thu (legacy)' },
  { value: 'COMPLETED', label: 'COMPLETED · Đã thu (legacy)' },
  { value: 'FAILED', label: 'FAILED · Thất bại' },
  { value: 'REFUNDED', label: 'REFUNDED · Đã hoàn' },
]

function formatDate(value: string | null) {
  if (!value) return '—'
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? value : new Intl.DateTimeFormat('vi-VN', { dateStyle: 'medium', timeStyle: 'short' }).format(date)
}

function statusClass(status: PaymentStatus) {
  if (status === 'PAID') return 'bg-success/10 text-success'
  if (status === 'FAILED' || status === 'REFUNDED') return 'bg-destructive/10 text-destructive'
  return ''
}

function ReconcileAction({ payment }: { payment: Payment }) {
  const client = useQueryClient()
  const notify = useFeedback()
  const initiatingIdentity = useRef<ReturnType<typeof identityOf>>(null)
  const [result, setResult] = useState<PaymentReconcile['result']>('PAID')
  const [providerTransactionId, setProviderTransactionId] = useState('')
  const [note, setNote] = useState('')
  const mutation = useMutation({
    retry: false,
    mutationFn: () => {
      const expected = initiatingIdentity.current
      if (!expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      return backend.reconcilePayment(payment.paymentId, { result, providerTransactionId: providerTransactionId || undefined, note })
    },
    onSuccess: async data => {
      const expected = initiatingIdentity.current
      if (!expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      await paymentChangeConfirmed(client, expected.id, data)
      if (!sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      notify(data.status === 'PAID' ? 'Đã ghi nhận thanh toán PAID sau khi đối soát.' : 'Đã ghi nhận thanh toán FAILED.')
    },
    onError: async error => {
      const expected = initiatingIdentity.current
      if (!extractApiError(error).outcomeUnknown || !expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) return
      await paymentChangeConfirmed(client, expected.id)
    },
  })
  const parsed = paymentReconcileSchema.safeParse({ result, providerTransactionId: providerTransactionId || undefined, note })
  return <ConfirmDialog
    trigger={<Button variant="outline" disabled={mutation.isPending}><ShieldCheck className="size-4" />Đối soát</Button>}
    title="Xác nhận đối soát thanh toán"
    description="Chỉ ghi nhận kết quả chuyển khoản đã được Admin xác minh bên ngoài hệ thống. VietCast không gửi lệnh tới ngân hàng."
    confirmLabel="Xác nhận đối soát"
    confirmDisabled={!parsed.success || mutation.isPending}
    onOpenChange={open => {
      initiatingIdentity.current = open ? identityOf(session.getUser()) : null
      if (open) { setResult('PAID'); setProviderTransactionId(''); setNote(''); mutation.reset() }
    }}
    onConfirm={async () => { await mutation.mutateAsync() }}
  >
    <div className="space-y-4">
      <label className="field-label" htmlFor={`payment-result-${payment.paymentId}`}>Kết quả *</label>
      <select id={`payment-result-${payment.paymentId}`} className="field" value={result} onChange={event => setResult(event.target.value as PaymentReconcile['result'])}>
        <option value="PAID">PAID · Đã xác minh chuyển khoản</option>
        <option value="FAILED">FAILED · Không nhận được tiền</option>
      </select>
      <div>
        <label className="field-label" htmlFor={`payment-reference-${payment.paymentId}`}>Mã giao dịch ngân hàng {result === 'PAID' ? '*' : ''}</label>
        <input id={`payment-reference-${payment.paymentId}`} className="field font-mono text-xs" maxLength={180} value={providerTransactionId} onChange={event => setProviderTransactionId(event.target.value)} placeholder={result === 'PAID' ? 'BANK-TRANSFER-001' : 'Không bắt buộc khi FAILED'} />
        {result === 'PAID' && !providerTransactionId.trim() && <p className="field-error">Cần mã giao dịch đã đối soát.</p>}
      </div>
      <div>
        <label className="field-label" htmlFor={`payment-reconcile-note-${payment.paymentId}`}>Ghi chú *</label>
        <textarea id={`payment-reconcile-note-${payment.paymentId}`} className="field py-3" rows={4} maxLength={5000} value={note} onChange={event => setNote(event.target.value)} placeholder="Nội dung đã kiểm tra giao dịch" />
      </div>
    </div>
  </ConfirmDialog>
}

function RefundAction({ payment }: { payment: Payment }) {
  const client = useQueryClient()
  const notify = useFeedback()
  const initiatingIdentity = useRef<ReturnType<typeof identityOf>>(null)
  const [refundReference, setRefundReference] = useState('')
  const [note, setNote] = useState('')
  const mutation = useMutation({
    retry: false,
    mutationFn: () => {
      const expected = initiatingIdentity.current
      if (!expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      return backend.refundPayment(payment.paymentId, { refundReference, note })
    },
    onSuccess: async data => {
      const expected = initiatingIdentity.current
      if (!expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      await paymentChangeConfirmed(client, expected.id, data)
      if (!sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      notify('Đã ghi nhận hoàn tiền thủ công theo mã đã xác minh.')
    },
    onError: async error => {
      const expected = initiatingIdentity.current
      if (!extractApiError(error).outcomeUnknown || !expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) return
      await paymentChangeConfirmed(client, expected.id)
    },
  })
  const parsed = paymentRefundSchema.safeParse({ refundReference, note })
  return <ConfirmDialog
    trigger={<Button variant="destructive" disabled={mutation.isPending}><RotateCcw className="size-4" />Ghi nhận hoàn tiền</Button>}
    title="Xác nhận ghi nhận hoàn tiền"
    description="Chỉ sử dụng sau khi Admin đã chuyển trả toàn bộ tiền bên ngoài hệ thống. Backend sẽ đổi payment thành REFUNDED và hủy subscription nếu có."
    confirmLabel="Xác nhận hoàn tiền"
    destructive
    confirmDisabled={!parsed.success || mutation.isPending}
    onOpenChange={open => {
      initiatingIdentity.current = open ? identityOf(session.getUser()) : null
      if (open) { setRefundReference(''); setNote(''); mutation.reset() }
    }}
    onConfirm={async () => { await mutation.mutateAsync() }}
  >
    <div className="space-y-4">
      <div>
        <label className="field-label" htmlFor={`payment-refund-reference-${payment.paymentId}`}>Mã hoàn tiền *</label>
        <input id={`payment-refund-reference-${payment.paymentId}`} className="field font-mono text-xs" maxLength={180} value={refundReference} onChange={event => setRefundReference(event.target.value)} placeholder="BANK-REFUND-001" />
      </div>
      <div>
        <label className="field-label" htmlFor={`payment-refund-note-${payment.paymentId}`}>Ghi chú *</label>
        <textarea id={`payment-refund-note-${payment.paymentId}`} className="field py-3" rows={4} maxLength={5000} value={note} onChange={event => setNote(event.target.value)} placeholder="Nội dung đã chuyển trả toàn bộ tiền" />
      </div>
    </div>
  </ConfirmDialog>
}

function PaymentDetail({ paymentId, fallback, onClose }: { paymentId: string; fallback?: Payment; onClose: () => void }) {
  const { user } = useAuth()
  const query = useQuery({ queryKey: adminKeys.paymentDetail(user?.id, paymentId), enabled: user?.role === 'ADMIN', queryFn: ({ signal }) => backend.payment(paymentId, signal) })
  const payment = query.data || fallback
  return <section className="panel h-fit"><div className="panel-heading"><div><p className="eyebrow">Chi tiết thanh toán</p><h2 className="mt-1 text-lg font-semibold">{payment ? formatMoney(payment.amount, payment.currency) : 'Đang tải…'}</h2></div><Button variant="ghost" onClick={onClose}>Đóng</Button></div>
    {query.isPending && !payment ? <LoadingState /> : query.isError && !payment ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : payment ? <div className="space-y-5 p-6 text-sm">
      <div className="flex flex-wrap items-center justify-between gap-3"><span className={`badge ${statusClass(payment.status)}`}>{payment.status}</span><span className="text-xs text-muted-foreground">Tạo lúc {formatDate(payment.createdAt)}</span></div>
      {query.isError && <p role="alert" className="rounded-lg bg-destructive/10 p-3 text-sm text-destructive">Chưa tải được chi tiết mới nhất: {errorMessage(query.error)}. Dữ liệu đang hiển thị là bản ghi trong danh sách.</p>}
      <div className="grid gap-4 sm:grid-cols-2"><div><p className="text-xs text-muted-foreground">Payment ID</p><p className="mt-1 break-all font-mono text-xs">{payment.paymentId}</p></div><div><p className="text-xs text-muted-foreground">User ID</p><p className="mt-1 break-all font-mono text-xs">{payment.userId}</p></div><div><p className="text-xs text-muted-foreground">Subscription ID</p><p className="mt-1 break-all font-mono text-xs">{payment.subscriptionId || '—'}</p></div><div><p className="text-xs text-muted-foreground">Request / Stage</p><p className="mt-1 break-all font-mono text-xs">{payment.requestId || payment.stageId || '—'}</p></div><div><p className="text-xs text-muted-foreground">Provider</p><p className="mt-1">{payment.provider || '—'}</p></div><div><p className="text-xs text-muted-foreground">Mã giao dịch</p><p className="mt-1 break-all font-mono text-xs">{payment.providerTransactionId || '—'}</p></div><div><p className="text-xs text-muted-foreground">Đã thu lúc</p><p className="mt-1">{formatDate(payment.paidAt)}</p></div><div><p className="text-xs text-muted-foreground">Mã hoàn tiền / lúc hoàn</p><p className="mt-1 break-all font-mono text-xs">{payment.refundReference || '—'}{payment.refundedAt ? ` · ${formatDate(payment.refundedAt)}` : ''}</p></div></div>
      <div className="rounded-lg bg-muted/50 p-4"><p className="text-xs text-muted-foreground">Khả năng hoàn tiền</p><p className="mt-1 font-medium">{(['PAID', 'SUCCESS', 'COMPLETED'] as string[]).includes(payment.status) ? 'Có thể ghi nhận hoàn tiền toàn bộ sau khi đã chuyển trả bên ngoài hệ thống.' : payment.status === 'REFUNDED' ? 'Đã ghi nhận hoàn tiền.' : 'Chưa đủ điều kiện theo trạng thái Backend hiện tại.'}</p></div>
      {payment.status === 'PENDING' && <ReconcileAction payment={payment} />}
      {(['PAID', 'SUCCESS', 'COMPLETED'] as string[]).includes(payment.status) && <RefundAction payment={payment} />}
      <p className="text-xs leading-5 text-muted-foreground">Các thao tác tài chính chỉ ghi nhận sự kiện đã xác minh. Không có thanh toán, hoàn tiền hoặc gọi ngân hàng tự động từ AdminWeb.</p>
    </div> : <EmptyState title="Không tìm thấy payment" message="Payment có thể đã thay đổi hoặc không còn tồn tại." />}
  </section>
}

export function PaymentsPage() {
  const { user } = useAuth()
  const [status, setStatus] = useState<PaymentStatus | ''>('PENDING')
  const [page, setPage] = useState(0)
  const [selected, setSelected] = useState<string | null>(null)
  const query = useQuery({ queryKey: adminKeys.paymentList(user?.id, status, page, pageSize), enabled: user?.role === 'ADMIN', queryFn: ({ signal }) => backend.payments({ status, page, size: pageSize }, signal) })
  const totalPages = Math.max(1, query.data?.totalPages || 0)
  return <><div className="mb-7 flex flex-wrap items-end justify-between gap-4"><div><p className="eyebrow">Tài chính</p><h1 className="mt-2 text-3xl font-bold">Payments & Refunds</h1><p className="mt-2 text-sm text-muted-foreground">Đối soát thanh toán và ghi nhận hoàn tiền thủ công theo contract Backend.</p></div><Button variant="outline" disabled={query.isFetching} onClick={() => { void query.refetch() }}><RefreshCw className={`size-4 ${query.isFetching ? 'motion-safe:animate-spin' : ''}`} />Làm mới</Button></div>
    <section className="panel mb-6"><div className="grid gap-3 p-5 sm:grid-cols-[minmax(0,1fr)_220px]"><div><p className="text-xs leading-5 text-muted-foreground">Không gửi lệnh chuyển tiền. Chỉ Admin được truy cập và mọi thay đổi phải được Backend xác nhận.</p></div><label><span className="sr-only">Lọc trạng thái payment</span><select className="field" value={status} onChange={event => { setStatus(event.target.value as PaymentStatus | ''); setPage(0); setSelected(null) }}>{statusOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}</select></label></div></section>
    <div><section className="panel"><div className="panel-heading"><div><h2 className="font-semibold">Danh sách payment</h2><p className="mt-1 text-xs text-muted-foreground">{query.data ? `${query.data.totalElements} payment · trang ${query.data.number + 1}/${totalPages}` : 'Phân trang từ Backend'}</p></div></div>
      {query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : query.data?.content.length ? <><div className="overflow-x-auto"><table className="data-table"><thead><tr><th>Payment</th><th>Người dùng</th><th>Số tiền</th><th>Trạng thái</th><th>Ngày tạo</th><th><span className="sr-only">Thao tác</span></th></tr></thead><tbody>{query.data.content.map(payment => <Fragment key={payment.paymentId}><tr className={selected === payment.paymentId ? 'bg-muted/40' : ''}><td><p className="font-semibold">{payment.paymentId.slice(0, 8)}…</p><p className="mt-1 break-all font-mono text-[11px] text-muted-foreground">{payment.providerTransactionId || 'Chưa có mã giao dịch'}</p></td><td className="max-w-44 break-all font-mono text-[11px]">{payment.userId}</td><td className="whitespace-nowrap font-semibold">{formatMoney(payment.amount, payment.currency)}</td><td><span className={`badge ${statusClass(payment.status)}`}>{payment.status}</span></td><td className="whitespace-nowrap text-xs">{formatDate(payment.createdAt)}</td><td><Button variant="outline" onClick={() => setSelected(payment.paymentId)}><Eye className="size-4" />Chi tiết</Button></td></tr>{selected === payment.paymentId && <tr><td colSpan={6} className="p-0"><PaymentDetail paymentId={selected} fallback={query.data?.content.find(item => item.paymentId === selected)} onClose={() => setSelected(null)} /></td></tr>}</Fragment>)}</tbody></table></div><div className="flex items-center justify-between border-t border-border/60 px-5 py-4 text-sm"><Button variant="outline" disabled={page === 0} onClick={() => setPage(page - 1)}>Trước</Button><span className="text-muted-foreground">Trang {page + 1}/{totalPages}</span><Button variant="outline" disabled={page + 1 >= totalPages} onClick={() => setPage(page + 1)}>Sau</Button></div></> : <EmptyState title="Chưa có payment" message="Không có payment phù hợp với trạng thái hiện tại." />}
    </section></div>
    <p className="mt-4 text-xs text-muted-foreground">Refund chỉ được ghi nhận sau khi Admin đã chuyển trả toàn bộ tiền bên ngoài hệ thống; Backend sẽ từ chối nếu payment đã giải ngân vào ví.</p>
  </>
}
