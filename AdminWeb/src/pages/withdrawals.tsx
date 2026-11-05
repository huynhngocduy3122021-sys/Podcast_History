import { Fragment, useRef, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Eye, RefreshCw } from 'lucide-react'
import { useAuth } from '../auth'
import { api, errorMessage, session } from '../lib/client'
import { extractApiError } from '../lib/api-error'
import { createAdminApi } from '../lib/admin-api'
import { adminKeys, payoutChangeConfirmed } from '../lib/admin-cache'
import { payoutResultWriteSchema } from '../lib/admin-contracts'
import type { PayoutResultWrite, PayoutWithdrawal } from '../lib/admin-contracts'
import { identityOf, sameIdentity } from '../lib/identity'
import { formatDate, formatMoney } from '../lib/finance-format'
import { Button } from '../components/ui/button'
import { ConfirmDialog } from '../components/ui/confirm-dialog'
import { EmptyState, ErrorState, LoadingState } from '../components/states'
import { useFeedback } from '../components/feedback'

const backend = createAdminApi(api)
const sessionChangedMessage = 'Phiên đăng nhập đã thay đổi. Vui lòng tải lại dữ liệu trước khi tiếp tục.'

function CreatorDeclaredAccounts() {
  const { user } = useAuth()
  const client = useQueryClient()
  const notify = useFeedback()
  const queryKey = ['creator-payout-accounts', user?.id] as const
  const query = useQuery({
    queryKey,
    enabled: user?.role === 'ADMIN',
    queryFn: ({ signal }) => backend.allCreatorPayoutAccounts(signal),
  })
  const verification = useMutation({
    mutationFn: (account: { creatorProfileId: string; payoutAccountId: string }) =>
      backend.verifyCreatorPayoutAccount(account.creatorProfileId, account.payoutAccountId),
    onSuccess: async () => {
      await client.invalidateQueries({ queryKey })
      notify('Đã xác minh tài khoản nhận tiền.')
    },
  })
  const confirmVerification = async (account: { creatorProfileId: string; payoutAccountId: string }) => {
    try {
      await verification.mutateAsync(account)
    } catch (error) {
      if (extractApiError(error).outcomeUnknown) {
        const latest = await query.refetch()
        if (latest.data?.some(item => item.payoutAccountId === account.payoutAccountId && item.verified)) {
          verification.reset()
          notify('Tài khoản đã được xác minh.')
          return
        }
      }
      throw error
    }
  }
  return <section className="panel mb-6">
    <div className="panel-heading"><div><h2 className="font-semibold">Tài khoản nhận tiền của CC</h2><p className="mt-1 text-xs text-muted-foreground">Danh sách CC tự khai báo; tài khoản chưa xác minh được hiển thị trước.</p></div><Button variant="outline" disabled={query.isFetching} onClick={() => { verification.reset(); void query.refetch() }}><RefreshCw className="size-4" />Làm mới</Button></div>
    <div className="px-6 pb-6 pt-4">
      {query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : query.data?.length ?
        <ul className="divide-y divide-border/60 rounded-lg border border-border/60">{query.data.map(account => <li key={account.payoutAccountId} className="flex flex-wrap items-center justify-between gap-4 p-4 text-sm">
          <div><p className="font-semibold">{account.channelName} · {account.creatorName}</p><p className="mt-1 text-xs text-muted-foreground">{account.creatorEmail}</p><p className="mt-2">{account.accountMasked}</p><p className="mt-1 font-mono text-xs">{account.accountReference}</p><p className="mt-1 text-xs text-muted-foreground">{account.verified ? 'Đã xác minh' : 'Chưa xác minh'} · {account.active ? 'Đang hoạt động' : 'Không hoạt động'}</p></div>
          {!account.verified && account.active && <ConfirmDialog trigger={<Button variant="outline" disabled={verification.isPending}>Xác minh</Button>} title="Xác minh tài khoản nhận tiền?" description="Chỉ xác minh sau khi đã đối soát chủ tài khoản và số tài khoản bên ngoài hệ thống." confirmLabel="Đã đối soát" confirmDisabled={verification.isPending} onConfirm={() => confirmVerification(account)} />}
        </li>)}</ul> : <EmptyState title="Chưa có tài khoản" message="CC chưa khai báo tài khoản ngân hàng nhận tiền." />}
      {verification.isError && <p role="alert" className="mt-3 field-error">{errorMessage(verification.error)}</p>}
    </div>
  </section>
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
  return <ConfirmDialog trigger={<Button variant="outline"><Eye className="size-4" />Xử lý</Button>} title="Ghi nhận kết quả payout" description="Chỉ ghi SUCCESS sau khi Admin đã chuyển khoản ngoài hệ thống và đối soát mã giao dịch. FAILED sẽ hoàn tiền đang giữ về ví." confirmLabel="Ghi nhận" confirmDisabled={!parsed.success || mutation.isPending} onOpenChange={open => { initiatingIdentity.current = open ? identityOf(session.getUser()) : null; if (open) { setResult('SUCCESS'); setProviderReference(''); setNote(''); mutation.reset() } }} onConfirm={async () => { await mutation.mutateAsync() }}><div className="space-y-4"><div><label className="field-label" htmlFor={`payout-result-${payout.withdrawalRequestId}`}>Kết quả *</label><select id={`payout-result-${payout.withdrawalRequestId}`} className="field mt-2" value={result} onChange={event => setResult(event.target.value as PayoutResultWrite['result'])}><option value="SUCCESS">SUCCESS — đã chuyển khoản và đối soát</option><option value="FAILED">FAILED — chuyển thất bại</option></select></div>{result === 'SUCCESS' && <div><label className="field-label" htmlFor={`payout-reference-${payout.withdrawalRequestId}`}>Provider reference *</label><input id={`payout-reference-${payout.withdrawalRequestId}`} className="field mt-2" value={providerReference} onChange={event => setProviderReference(event.target.value)} /></div>}<div><label className="field-label" htmlFor={`payout-note-${payout.withdrawalRequestId}`}>Ghi chú</label><textarea id={`payout-note-${payout.withdrawalRequestId}`} className="field mt-2 py-3" rows={4} maxLength={5000} value={note} onChange={event => setNote(event.target.value)} /></div>{mutation.isError && <p role="alert" className="field-error">{errorMessage(mutation.error)}</p>}</div></ConfirmDialog>
}

function PayoutDetail({ payout, onClose, onDone }: { payout: PayoutWithdrawal; onClose: () => void; onDone: () => void }) {
  return <section className="panel mt-4"><div className="panel-heading"><div><p className="eyebrow">Pending payout</p><h3 className="text-lg font-semibold">{formatMoney(payout.amount, payout.currency)}</h3></div><Button variant="ghost" onClick={onClose}>Đóng</Button></div><div className="space-y-5 p-6 text-sm"><div className="grid gap-4 sm:grid-cols-2"><p>Withdrawal ID<br /><span className="break-all font-mono text-xs">{payout.withdrawalRequestId}</span></p><p>Creator profile<br /><span className="break-all font-mono text-xs">{payout.creatorProfileId}</span></p><p>Phương thức<br />{payout.payoutMethod}</p><p>Tài khoản<br />{payout.payoutAccountMasked}</p><p>Reference<br /><span className="break-all font-mono text-xs">{payout.payoutAccountReference || '—'}</span></p><p>Yêu cầu lúc<br />{formatDate(payout.requestedAt)}</p></div><p className="whitespace-pre-wrap rounded-lg bg-muted/50 p-4">{payout.note || 'Không có ghi chú.'}</p><PayoutResultAction payout={payout} onDone={onDone} /></div></section>
}

export function WithdrawalsPage() {
  const { user } = useAuth()
  const [selected, setSelected] = useState<string | null>(null)
  const query = useQuery({ queryKey: adminKeys.payouts(user?.id), enabled: user?.role === 'ADMIN', queryFn: ({ signal }) => backend.pendingPayouts(signal) })
  const data = query.data || []
  return <><div className="mb-7 flex flex-wrap items-end justify-between gap-4"><div><p className="eyebrow">Tài chính</p><h1 className="mt-2 text-3xl font-bold">Creator payouts</h1><p className="mt-2 text-sm text-muted-foreground">Xử lý các withdrawal đã giữ tiền theo payout contract hiện tại.</p></div><Button variant="outline" disabled={query.isFetching} onClick={() => { void query.refetch() }}><RefreshCw className="size-4" />Làm mới</Button></div><CreatorDeclaredAccounts /><section className="panel"><div className="panel-heading"><div><h2 className="font-semibold">Withdrawal đang chờ payout</h2><p className="mt-1 text-xs text-muted-foreground">{query.data ? `${data.length} yêu cầu đang chờ` : 'Dữ liệu từ Backend'}</p></div></div>{query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : data.length ? <ul className="divide-y divide-border/60">{data.map(payout => <Fragment key={payout.withdrawalRequestId}><li className="flex flex-wrap items-center justify-between gap-4 p-5"><div className="min-w-0"><p className="font-semibold">{formatMoney(payout.amount, payout.currency)}</p><p className="mt-1 break-all font-mono text-xs text-muted-foreground">{payout.withdrawalRequestId}</p><p className="mt-1 text-sm">{payout.payoutMethod} · {payout.payoutAccountMasked}</p></div><div className="flex items-center gap-2"><span className="badge">{payout.status}</span><Button variant="outline" onClick={() => setSelected(selected === payout.withdrawalRequestId ? null : payout.withdrawalRequestId)}><Eye className="size-4" />Chi tiết</Button></div></li>{selected === payout.withdrawalRequestId && <li className="p-5"><PayoutDetail payout={payout} onClose={() => setSelected(null)} onDone={() => { setSelected(null); void query.refetch() }} /></li>}</Fragment>)}</ul> : <EmptyState title="Không có payout đang chờ" message="Các withdrawal Creator mới sẽ xuất hiện tại đây sau khi Backend giữ tiền." />}</section></>
}
