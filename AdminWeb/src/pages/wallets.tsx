import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Eye, RefreshCw } from 'lucide-react'
import { useAuth } from '../auth'
import { api, errorMessage } from '../lib/client'
import { createAdminApi } from '../lib/admin-api'
import { adminKeys } from '../lib/admin-cache'
import type { Wallet } from '../lib/admin-contracts'
import { formatDate, formatMoney, statusClass } from '../lib/finance-format'
import { Button } from '../components/ui/button'
import { EmptyState, ErrorState, LoadingState } from '../components/states'

const backend = createAdminApi(api)
const pageSize = 20
const transactionStatuses = ['', 'PENDING', 'COMPLETED', 'FAILED'] as const

function TransactionHistory({ wallet }: { wallet: Wallet }) {
  const { user } = useAuth()
  const [status, setStatus] = useState<string>('')
  const [page, setPage] = useState(0)
  const query = useQuery({
    queryKey: adminKeys.walletTransactions(user?.id, wallet.walletId, status, page, pageSize),
    enabled: user?.role === 'ADMIN',
    queryFn: ({ signal }) => backend.walletTransactions({ walletId: wallet.walletId, status, page, size: pageSize }, signal),
  })
  const totalPages = Math.max(1, query.data?.totalPages || 0)
  return <section className="mt-6 rounded-xl border border-border/70"><div className="flex flex-wrap items-center justify-between gap-3 border-b border-border/60 p-5"><div><h3 className="font-semibold">Lịch sử ledger</h3><p className="mt-1 text-xs text-muted-foreground">Số dư sau giao dịch do Backend trả về; AdminWeb không tự cộng/trừ ledger.</p></div><select className="field max-w-48" value={status} onChange={event => { setStatus(event.target.value); setPage(0) }} aria-label="Lọc trạng thái giao dịch">{transactionStatuses.map(value => <option key={value} value={value}>{value || 'Mọi trạng thái'}</option>)}</select></div>
    {query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : query.data?.content.length ? <><div className="overflow-x-auto"><table className="data-table"><thead><tr><th>Thời điểm</th><th>Loại / hướng</th><th>Số tiền</th><th>Trạng thái</th><th>Số dư sau giao dịch</th><th>Tham chiếu</th></tr></thead><tbody>{query.data.content.map(transaction => <tr key={transaction.transactionId}><td className="whitespace-nowrap text-xs">{formatDate(transaction.createdAt)}</td><td><p className="font-semibold">{transaction.type}</p><p className="mt-1 text-xs text-muted-foreground">{transaction.direction}</p></td><td className="whitespace-nowrap">{formatMoney(transaction.amount, transaction.currency)}</td><td><span className={`badge ${statusClass(transaction.status)}`}>{transaction.status}</span></td><td className="whitespace-nowrap">{transaction.balanceAfter === null ? '—' : formatMoney(transaction.balanceAfter, transaction.currency)}</td><td className="max-w-52 break-all font-mono text-[11px]">{transaction.referenceCode || '—'}</td></tr>)}</tbody></table></div><div className="flex items-center justify-between border-t border-border/60 px-5 py-4 text-sm"><Button variant="outline" disabled={page === 0} onClick={() => setPage(page - 1)}>Trước</Button><span className="text-muted-foreground">Trang {page + 1}/{totalPages}</span><Button variant="outline" disabled={page + 1 >= totalPages} onClick={() => setPage(page + 1)}>Sau</Button></div></> : <EmptyState title="Chưa có giao dịch" message="Không có ledger transaction phù hợp với ví và bộ lọc hiện tại." />}
  </section>
}

function WalletDetail({ wallet, onClose }: { wallet: Wallet; onClose: () => void }) {
  return <section className="panel h-fit"><div className="panel-heading"><div><p className="eyebrow">Chi tiết ví</p><h2 className="mt-1 text-lg font-semibold">{formatMoney(wallet.availableBalance, wallet.currency)}</h2></div><Button variant="ghost" onClick={onClose}>Đóng</Button></div><div className="space-y-5 p-6 text-sm"><div className="flex items-center justify-between gap-3"><span className={`badge ${statusClass(wallet.status)}`}>{wallet.status}</span><span className="text-xs text-muted-foreground">Số dư khả dụng từ Backend</span></div><div className="space-y-3"><div><p className="text-xs text-muted-foreground">Wallet ID</p><p className="mt-1 break-all font-mono text-xs">{wallet.walletId}</p></div><div><p className="text-xs text-muted-foreground">User ID</p><p className="mt-1 break-all font-mono text-xs">{wallet.userId}</p></div><div><p className="text-xs text-muted-foreground">Available balance</p><p className="mt-1 text-2xl font-semibold">{formatMoney(wallet.availableBalance, wallet.currency)}</p></div><div><p className="text-xs text-muted-foreground">Currency</p><p className="mt-1">{wallet.currency}</p></div></div><p className="text-xs leading-5 text-muted-foreground">Backend hiện chỉ cung cấp available balance; không có DTO pending/reserved balance hoặc endpoint điều chỉnh số dư. Không tự suy diễn từ ledger.</p><TransactionHistory wallet={wallet} /></div></section>
}

export function WalletsPage() {
  const { user } = useAuth()
  const [page, setPage] = useState(0)
  const [selected, setSelected] = useState<string | null>(null)
  const query = useQuery({ queryKey: adminKeys.walletList(user?.id, page, pageSize), enabled: user?.role === 'ADMIN', queryFn: ({ signal }) => backend.wallets(page, pageSize, signal) })
  const totalPages = Math.max(1, query.data?.totalPages || 0)
  return <><div className="mb-7 flex flex-wrap items-end justify-between gap-4"><div><p className="eyebrow">Tài chính</p><h1 className="mt-2 text-3xl font-bold">Ví</h1><p className="mt-2 text-sm text-muted-foreground">Xem số dư khả dụng và ledger transaction do Backend cung cấp.</p></div><Button variant="outline" disabled={query.isFetching} onClick={() => { void query.refetch() }}><RefreshCw className={`size-4 ${query.isFetching ? 'motion-safe:animate-spin' : ''}`} />Làm mới</Button></div><div className={selected ? 'grid gap-6 xl:grid-cols-[minmax(0,1.35fr)_minmax(360px,.8fr)]' : ''}><section className="panel"><div className="panel-heading"><div><h2 className="font-semibold">Danh sách ví</h2><p className="mt-1 text-xs text-muted-foreground">{query.data ? `${query.data.totalElements} ví · trang ${query.data.number + 1}/${totalPages}` : 'Phân trang từ Backend'}</p></div></div>{query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : query.data?.content.length ? <><div className="overflow-x-auto"><table className="data-table"><thead><tr><th>Wallet ID</th><th>User ID</th><th>Available balance</th><th>Trạng thái</th><th><span className="sr-only">Thao tác</span></th></tr></thead><tbody>{query.data.content.map(wallet => <tr key={wallet.walletId} className={selected === wallet.walletId ? 'bg-muted/40' : ''}><td className="break-all font-mono text-xs">{wallet.walletId}</td><td className="break-all font-mono text-xs">{wallet.userId}</td><td className="whitespace-nowrap font-semibold">{formatMoney(wallet.availableBalance, wallet.currency)}</td><td><span className={`badge ${statusClass(wallet.status)}`}>{wallet.status}</span></td><td><Button variant="outline" onClick={() => setSelected(wallet.walletId)}><Eye className="size-4" />Chi tiết</Button></td></tr>)}</tbody></table></div><div className="flex items-center justify-between border-t border-border/60 px-5 py-4 text-sm"><Button variant="outline" disabled={page === 0} onClick={() => setPage(page - 1)}>Trước</Button><span className="text-muted-foreground">Trang {page + 1}/{totalPages}</span><Button variant="outline" disabled={page + 1 >= totalPages} onClick={() => setPage(page + 1)}>Sau</Button></div></> : <EmptyState title="Chưa có ví" message="Backend chưa trả về ví nào." />}</section>{selected && query.data?.content.find(wallet => wallet.walletId === selected) && <WalletDetail wallet={query.data.content.find(wallet => wallet.walletId === selected)!} onClose={() => setSelected(null)} />}</div><p className="mt-4 text-xs text-muted-foreground">Không có thao tác điều chỉnh số dư trong Backend contract hiện tại.</p></>
}
