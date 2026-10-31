import { Fragment, useRef, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Eye, RefreshCw } from 'lucide-react'
import { useAuth } from '../auth'
import { api, errorMessage, session } from '../lib/client'
import { extractApiError } from '../lib/api-error'
import { createAdminApi } from '../lib/admin-api'
import { adminKeys, payoutChangeConfirmed } from '../lib/admin-cache'
import { payoutAccountWriteSchema, payoutResultWriteSchema } from '../lib/admin-contracts'
import type { PayoutAccountWrite, PayoutResultWrite, PayoutWithdrawal } from '../lib/admin-contracts'
import { identityOf, sameIdentity } from '../lib/identity'
import { formatDate, formatMoney } from '../lib/finance-format'
import { Button } from '../components/ui/button'
import { ConfirmDialog } from '../components/ui/confirm-dialog'
import { EmptyState, ErrorState, LoadingState } from '../components/states'
import { useFeedback } from '../components/feedback'

const backend = createAdminApi(api)
const sessionChangedMessage = 'Phiên đăng nhập đã thay đổi. Vui lòng tải lại dữ liệu trước khi tiếp tục.'

function PayoutAccountForm() {
  const { user } = useAuth()
  const client = useQueryClient()
  const notify = useFeedback()
  const [creatorProfileId, setCreatorProfileId] = useState('')
  const [values, setValues] = useState<PayoutAccountWrite>({ payoutMethod: 'BANK', accountReference: '', accountMasked: '', currency: 'VND' })
  const mutation = useMutation({
    mutationFn: () => backend.registerPayoutAccount(creatorProfileId, values),
    onSuccess: async () => { await client.invalidateQueries({ queryKey: adminKeys.payouts(user?.id) }); notify('Đã đăng ký tài khoản nhận tiền đã xác minh.'); setCreatorProfileId(''); setValues({ payoutMethod: 'BANK', accountReference: '', accountMasked: '', currency: 'VND' }) },
  })
  const parsed = payoutAccountWriteSchema.safeParse(values)
  const validCreator = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(creatorProfileId)
  return <section className="panel mb-6"><div className="panel-heading"><div><h2 className="font-semibold">Đăng ký tài khoản payout</h2><p className="mt-1 text-xs text-muted-foreground">Chỉ dùng thông tin tài khoản đã được payout provider xác minh.</p></div></div><form className="grid gap-4 p-6 md:grid-cols-2" onSubmit={event => { event.preventDefault(); mutation.mutate() }}><label><span className="field-label">Creator profile ID *</span><input className="field font-mono text-xs" value={creatorProfileId} onChange={event => setCreatorProfileId(event.target.value)} />{creatorProfileId && !validCreator && <span className="field-error">UUID không hợp lệ.</span>}</label><label><span className="field-label">Phương thức *</span><input className="field" value={values.payoutMethod} onChange={event => setValues(current => ({ ...current, payoutMethod: event.target.value }))} /></label><label><span className="field-label">Account reference *</span><input className="field" value={values.accountReference} onChange={event => setValues(current => ({ ...current, accountReference: event.target.value }))} /></label><label><span className="field-label">Account masked *</span><input className="field" value={values.accountMasked} onChange={event => setValues(current => ({ ...current, accountMasked: event.target.value }))} /></label><label><span className="field-label">Currency *</span><input className="field uppercase" maxLength={3} value={values.currency} onChange={event => setValues(current => ({ ...current, currency: event.target.value }))} /></label><div className="flex items-end"><Button type="submit" disabled={!validCreator || !parsed.success || mutation.isPending}>{mutation.isPending ? 'Đang lưu…' : 'Đăng ký tài khoản'}</Button></div>{mutation.isError && <p role="alert" className="md:col-span-2 field-error">{errorMessage(mutation.error)}</p>}</form></section>
}

function PayoutResultAction({ payout, onDone }: { payout: PayoutWithdrawal; onDone: () => void }) {
  const client = useQueryClient()
  const notify = useFeedback()
  const initiatingIdentity = useRef<ReturnType<typeof identityOf>>(null)
  const [result, setResult] = useState<PayoutResultWrite['result']>('SUCCESS')
  const [providerReference, setProviderReference] = useState('')
  const [note, setNote] = useState('')
  const mutation = useMutation({
    retry: false,
    mutationFn: () => { const expected = initiatingIdentity.current; if (!expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage); return backend.recordPayoutResult(payout.withdrawalRequestId, { result, providerReference, note }) },
    onSuccess: async data => { const expected = initiatingIdentity.current; if (!expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage); await payoutChangeConfirmed(client, expected.id); if (!sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage); notify(data.status === 'COMPLETED' ? 'Đã ghi nhận payout thành công.' : 'Đã ghi nhận payout thất bại và hoàn tiền về ví.'); onDone() },
    onError: async error => { const expected = initiatingIdentity.current; if (extractApiError(error).outcomeUnknown && expected && sameIdentity(expected, identityOf(session.getUser()))) await payoutChangeConfirmed(client, expected.id) },
  })
  const parsed = payoutResultWriteSchema.safeParse({ result, providerReference, note })
  return <ConfirmDialog trigger={<Button variant="outline"><Eye className="size-4" />Xử lý</Button>} title="Ghi nhận kết quả payout" description="Backend sẽ chuyển withdrawal sang COMPLETED hoặc FAILED. FAILED sẽ hoàn khoản tiền đang giữ về số dư khả dụng." confirmLabel="Ghi nhận" confirmDisabled={!parsed.success || mutation.isPending} onOpenChange={open => { initiatingIdentity.current = open ? identityOf(session.getUser()) : null; if (open) { setResult('SUCCESS'); setProviderReference(''); setNote(''); mutation.reset() } }} onConfirm={async () => { await mutation.mutateAsync() }}><div className="space-y-4"><div><label className="field-label" htmlFor={`payout-result-${payout.withdrawalRequestId}`}>Kết quả *</label><select id={`payout-result-${payout.withdrawalRequestId}`} className="field mt-2" value={result} onChange={event => setResult(event.target.value as PayoutResultWrite['result'])}><option value="SUCCESS">SUCCESS — đã chuyển</option><option value="FAILED">FAILED — chuyển thất bại</option></select></div>{result === 'SUCCESS' && <div><label className="field-label" htmlFor={`payout-reference-${payout.withdrawalRequestId}`}>Provider reference *</label><input id={`payout-reference-${payout.withdrawalRequestId}`} className="field mt-2" value={providerReference} onChange={event => setProviderReference(event.target.value)} /></div>}<div><label className="field-label" htmlFor={`payout-note-${payout.withdrawalRequestId}`}>Ghi chú</label><textarea id={`payout-note-${payout.withdrawalRequestId}`} className="field mt-2 py-3" rows={4} maxLength={5000} value={note} onChange={event => setNote(event.target.value)} /></div>{mutation.isError && <p role="alert" className="field-error">{errorMessage(mutation.error)}</p>}</div></ConfirmDialog>
}

function PayoutDetail({ payout, onClose, onDone }: { payout: PayoutWithdrawal; onClose: () => void; onDone: () => void }) {
  return <section className="panel mt-4"><div className="panel-heading"><div><p className="eyebrow">Pending payout</p><h3 className="text-lg font-semibold">{formatMoney(payout.amount, payout.currency)}</h3></div><Button variant="ghost" onClick={onClose}>Đóng</Button></div><div className="space-y-5 p-6 text-sm"><div className="grid gap-4 sm:grid-cols-2"><p>Withdrawal ID<br /><span className="break-all font-mono text-xs">{payout.withdrawalRequestId}</span></p><p>Creator profile<br /><span className="break-all font-mono text-xs">{payout.creatorProfileId}</span></p><p>Phương thức<br />{payout.payoutMethod}</p><p>Tài khoản<br />{payout.payoutAccountMasked}</p><p>Reference<br /><span className="break-all font-mono text-xs">{payout.payoutAccountReference || '—'}</span></p><p>Yêu cầu lúc<br />{formatDate(payout.requestedAt)}</p></div><p className="whitespace-pre-wrap rounded-lg bg-muted/50 p-4">{payout.note || 'Không có ghi chú.'}</p><PayoutResultAction payout={payout} onDone={onDone} /></div></section>
}

export function WithdrawalsPage() {
  const { user } = useAuth()
  const [selected, setSelected] = useState<string | null>(null)
  const query = useQuery({ queryKey: adminKeys.payouts(user?.id), enabled: user?.role === 'ADMIN', queryFn: ({ signal }) => backend.pendingPayouts(signal) })
  const data = query.data || []
  return <><div className="mb-7 flex flex-wrap items-end justify-between gap-4"><div><p className="eyebrow">Tài chính</p><h1 className="mt-2 text-3xl font-bold">Creator payouts</h1><p className="mt-2 text-sm text-muted-foreground">Xử lý các withdrawal đã giữ tiền theo payout contract hiện tại.</p></div><Button variant="outline" disabled={query.isFetching} onClick={() => { void query.refetch() }}><RefreshCw className="size-4" />Làm mới</Button></div><PayoutAccountForm /><section className="panel"><div className="panel-heading"><div><h2 className="font-semibold">Withdrawal đang chờ payout</h2><p className="mt-1 text-xs text-muted-foreground">{query.data ? `${data.length} yêu cầu đang chờ` : 'Dữ liệu từ Backend'}</p></div></div>{query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : data.length ? <ul className="divide-y divide-border/60">{data.map(payout => <Fragment key={payout.withdrawalRequestId}><li className="flex flex-wrap items-center justify-between gap-4 p-5"><div className="min-w-0"><p className="font-semibold">{formatMoney(payout.amount, payout.currency)}</p><p className="mt-1 break-all font-mono text-xs text-muted-foreground">{payout.withdrawalRequestId}</p><p className="mt-1 text-sm">{payout.payoutMethod} · {payout.payoutAccountMasked}</p></div><div className="flex items-center gap-2"><span className="badge">{payout.status}</span><Button variant="outline" onClick={() => setSelected(selected === payout.withdrawalRequestId ? null : payout.withdrawalRequestId)}><Eye className="size-4" />Chi tiết</Button></div></li>{selected === payout.withdrawalRequestId && <li className="p-5"><PayoutDetail payout={payout} onClose={() => setSelected(null)} onDone={() => { setSelected(null); void query.refetch() }} /></li>}</Fragment>)}</ul> : <EmptyState title="Không có payout đang chờ" message="Các withdrawal Creator mới sẽ xuất hiện tại đây sau khi Backend giữ tiền." />}</section></>
}
