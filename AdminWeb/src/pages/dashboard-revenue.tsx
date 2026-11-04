import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useAuth } from '../auth'
import { EmptyState, ErrorState, LoadingState } from '../components/states'
import { Button } from '../components/ui/button'
import { api, errorMessage } from '../lib/client'
import { revenueDetailsPageSchema } from '../lib/contracts'
import { formatDate, formatMoney } from '../lib/finance-format'

export function DashboardRevenue() {
  const { user } = useAuth()
  const [page, setPage] = useState(0)
  const query = useQuery({
    queryKey: ['dashboard-revenue-details', user?.id, page],
    enabled: user?.role === 'ADMIN',
    queryFn: async ({ signal }) => revenueDetailsPageSchema.parse(
      (await api.get(`/api/admin/dashboard/revenue-details?page=${page}&size=20`, { signal })).data,
    ),
  })
  const data = query.data

  return <section className="panel mt-6">
    <div className="panel-heading"><div><h2 className="font-semibold">Chi tiết doanh thu</h2><p className="mt-1 text-xs text-muted-foreground">Các khoản đã quyết toán, phân trang theo dữ liệu Backend</p></div></div>
    {query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : data?.content.length ? <>
      <div className="overflow-x-auto"><table className="data-table"><thead><tr><th>Thời gian</th><th>Nguồn thu</th><th>Người thanh toán / CC</th><th>Tổng tiền</th><th>Phí app</th><th>CC nhận</th><th>Trạng thái / phương thức</th></tr></thead><tbody>
        {data.content.map(item => <tr key={item.paymentId || item.checkoutId}>
          <td className="whitespace-nowrap text-xs">{formatDate(item.paidAt)}</td>
          <td className="max-w-72"><p className="font-semibold">{item.sourceTypeLabel || item.sourceType}</p><p className="mt-1 break-words text-xs text-muted-foreground">{item.requestTitle || item.membershipPlanName || item.creatorPlanName || item.sourceLabel}{item.stageName ? ` · ${item.stageName}` : ''}</p><p className="mt-1 break-all font-mono text-[11px] text-muted-foreground">{item.checkoutId ? 'Checkout' : 'Payment'}: {item.checkoutId || item.paymentId}</p></td>
          <td className="max-w-52"><p>{item.buyerName || item.buyerEmail || '—'}</p><p className="mt-1 text-xs text-muted-foreground">{item.sourceType === 'CREATOR_PLAN' ? 'Kênh' : 'CC'}: {item.creatorChannelName || item.creatorName || '—'}</p></td>
          <td className="whitespace-nowrap font-semibold">{formatMoney(item.amount, item.currency)}</td>
          <td className="whitespace-nowrap">{formatMoney(item.platformFee, item.currency)}</td>
          <td className="whitespace-nowrap">{item.sourceType === 'CREATOR_PLAN' ? 'Không áp dụng' : formatMoney(item.creatorNetAmount, item.currency)}</td>
          <td><span className="badge whitespace-nowrap">{item.statusLabel || item.status}</span><p className="mt-1 text-xs text-muted-foreground">{item.paymentMethodLabel || item.paymentMethod || 'Không xác định'}</p></td>
        </tr>)}
      </tbody></table></div>
      <div className="flex items-center justify-between border-t border-border/60 px-5 py-4 text-sm"><Button variant="outline" disabled={page === 0 || query.isFetching} onClick={() => setPage(page - 1)}>Trước</Button><span className="text-muted-foreground">{data.totalElements} giao dịch · Trang {data.number + 1}/{Math.max(1, data.totalPages)}</span><Button variant="outline" disabled={page + 1 >= data.totalPages || query.isFetching} onClick={() => setPage(page + 1)}>Sau</Button></div>
    </> : <EmptyState title="Chưa có khoản thu" message="Chưa có giao dịch đã thanh toán để hiển thị." />}
  </section>
}
