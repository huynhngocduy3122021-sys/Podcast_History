import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { ArrowRight, Coins, Mic, RefreshCw, ShieldCheck, UserCheck, Users } from 'lucide-react'
import { Link } from 'react-router-dom'
import { useAuth } from '../auth'
import { api, errorMessage } from '../lib/client'
import { createAdminApi } from '../lib/admin-api'
import { formatDate, formatMoney, statusClass, statusLabel } from '../lib/finance-format'
import { isRole } from '../lib/permissions'
import { Button } from '../components/ui/button'
import { EmptyState, ErrorState, LoadingState } from '../components/states'
import { Pagination } from '../components/pagination'

const number = new Intl.NumberFormat('vi-VN')
const sourceLabels: Record<string, string> = {
  MEMBERSHIP: 'Gói thành viên',
  CONTRACT_STAGE: 'Giai đoạn hợp đồng',
  CONTRACT_DISPUTE: 'Tranh chấp hợp đồng',
  CONTRACT_COMPENSATION: 'Bồi thường hợp đồng',
  REQUEST: 'Yêu cầu',
  OTHER: 'Khác',
}

function sourceLabel(sourceType: string) {
  return sourceLabels[sourceType] || sourceType
}

function display(value: string | null | undefined) {
  return value?.trim() || '—'
}

export function DashboardPage() {
  const { user } = useAuth()
  const role = user?.role
  const admin = role === 'ADMIN'
  const backend = useMemo(() => createAdminApi(api), [])
  const [revenuePage, setRevenuePage] = useState(0)
  const query = useQuery({
    queryKey: ['dashboard', user?.id, role],
    enabled: isRole(role),
    queryFn: ({ signal }) => {
      if (!isRole(role)) throw new Error('Vai trò không hợp lệ.')
      return backend.dashboard(signal)
    },
  })
  const revenueQuery = useQuery({
    queryKey: ['dashboard-revenue-details', user?.id, role, revenuePage],
    enabled: isRole(role),
    queryFn: ({ signal }) => backend.revenueDetails(revenuePage, 20, signal),
  })
  const data = query.data
  const metrics = data ? [
    { label: 'Người dùng', value: data.users, detail: `${number.format(data.activeUsers)} đang hoạt động`, icon: Users },
    { label: 'Creator đã duyệt', value: data.creators, detail: admin ? `${number.format(data.pendingCreators)} hồ sơ chờ duyệt` : 'Kênh đã được phê duyệt', icon: UserCheck },
    { label: 'Podcast', value: data.podcasts, detail: `${number.format(data.pendingPodcasts)} chờ kiểm duyệt`, icon: Mic },
    { label: 'Báo cáo đang mở', value: data.pendingReports, detail: 'Chờ xử lý hoặc đang xem xét', icon: ShieldCheck },
  ] : []

  return <>
    <div className="mb-8 flex flex-wrap items-end justify-between gap-4">
      <div><p className="eyebrow">Không gian làm việc / {role}</p><h1 className="mt-2 text-3xl font-bold tracking-tight">Tổng quan vận hành</h1><p className="mt-2 text-sm text-muted-foreground">Theo dõi nội dung và các công việc cần xử lý.</p></div>
      <Button variant="outline" disabled={query.isFetching} onClick={() => { void query.refetch() }}><RefreshCw className={`size-4 ${query.isFetching ? 'motion-safe:animate-spin' : ''}`} />Làm mới</Button>
    </div>
    {query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : data && <>
      <div className="mb-8 flex items-center gap-2 text-xs text-muted-foreground"><span className="size-1.5 rounded-full bg-success" />Dữ liệu từ Backend · cập nhật {new Date(query.dataUpdatedAt).toLocaleTimeString('vi-VN')}</div>
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{metrics.map(m => <section key={m.label} className="panel p-5"><div className="flex items-center justify-between"><h2 className="text-sm font-medium text-muted-foreground">{m.label}</h2><m.icon className="size-5 text-bronze" aria-hidden="true" /></div><p className="mt-5 text-4xl font-semibold tracking-tight">{number.format(m.value)}</p><p className="mt-3 text-xs text-muted-foreground">{m.detail}</p></section>)}</div>
      <div className="mt-6 grid gap-6 xl:grid-cols-[1.4fr_1fr]">
        <section className="panel"><div className="panel-heading"><div><h2 className="font-semibold">Trạng thái nội dung</h2><p className="mt-1 text-xs text-muted-foreground">Phân bố podcast theo trạng thái Backend</p></div><Mic className="size-5 text-muted-foreground" /></div>{data.podcastStatuses.length ? <div className="space-y-5 p-6">{data.podcastStatuses.map((s, i) => <div key={`${s.status}-${i}`}><div className="mb-2 flex justify-between gap-3 text-sm"><span>{s.status || 'Chưa có trạng thái'}</span><span className="font-semibold">{number.format(s.count)}</span></div><div className="h-2 overflow-hidden rounded-full bg-muted"><div className="h-full rounded-full bg-primary/80" style={{ width: `${data.podcasts ? Math.min(100, s.count / data.podcasts * 100) : 0}%` }} /></div></div>)}</div> : <EmptyState title="Chưa có podcast" message="Trạng thái sẽ xuất hiện khi Backend có dữ liệu." />}</section>
        <section className="panel"><div className="panel-heading"><h2 className="font-semibold">Cần chú ý</h2><span className="badge">Hàng đợi</span></div><div className="divide-y divide-border px-6">{[
          { label: 'Podcast chờ kiểm duyệt', count: data.pendingPodcasts, path: '/podcast-moderation' },
          { label: 'Báo cáo chưa kết thúc', count: data.pendingReports, path: '/reports' },
          ...(admin ? [{ label: 'Hồ sơ Creator', count: data.pendingCreators, path: '/creator-approval' }, { label: 'Yêu cầu rút tiền', count: data.pendingWithdrawals, path: '/withdrawals' }, { label: 'Tranh chấp đang mở', count: data.openDisputes, path: '/disputes' }] : []),
        ].map(item => <Link to={item.path} key={item.path} className="flex items-center gap-3 py-5 text-sm hover:text-primary"><span className="flex-1">{item.label}</span><span className="font-bold">{number.format(item.count)}</span><ArrowRight className="size-4" /></Link>)}</div><p className="border-t border-border px-6 py-4 text-xs text-muted-foreground">Theo dõi các chỉ số vận hành và hàng đợi cần xử lý theo quyền của tài khoản.</p></section>
      </div>
      <>
        <section className="panel mt-6"><div className="panel-heading"><div><h2 className="font-semibold">Phân tích doanh thu</h2><p className="mt-1 text-xs text-muted-foreground">Số liệu được tổng hợp trực tiếp từ Backend theo từng loại tiền tệ</p></div><Coins className="size-5 text-muted-foreground" /></div>{data.revenueBreakdown.length ? <div className="grid gap-4 p-6 sm:grid-cols-2 xl:grid-cols-3">{data.revenueBreakdown.map(item => <div key={item.currency} className="rounded-lg border border-border p-4"><p className="text-xs font-medium text-muted-foreground">{item.currency}</p><dl className="mt-4 space-y-3 text-sm"><div className="flex justify-between gap-3"><dt className="text-muted-foreground">Gross collected</dt><dd className="font-semibold">{formatMoney(item.grossCollected, item.currency)}</dd></div><div className="flex justify-between gap-3"><dt className="text-muted-foreground">Platform fees</dt><dd className="font-semibold">{formatMoney(item.platformFees, item.currency)}</dd></div><div className="flex justify-between gap-3 border-t border-border pt-3"><dt className="text-muted-foreground">Net revenue</dt><dd className="font-semibold text-primary">{formatMoney(item.netRevenue, item.currency)}</dd></div></dl></div>)}</div> : <EmptyState title="Chưa có dữ liệu doanh thu" message="Backend chưa trả về số liệu tổng hợp." />}<p className="px-6 pb-5 text-xs text-muted-foreground">Các giá trị được hiển thị theo response Backend; không cộng gộp giữa các currency và không tính lại ở frontend.</p></section>
        <section className="panel mt-6"><div className="panel-heading"><div><h2 className="font-semibold">Chi tiết doanh thu</h2><p className="mt-1 text-xs text-muted-foreground">Các payment đã thu thành công, gồm cả nguồn thành viên, hợp đồng và yêu cầu.</p></div></div>{revenueQuery.isPending ? <LoadingState /> : revenueQuery.isError ? <ErrorState message={errorMessage(revenueQuery.error)} onRetry={() => { void revenueQuery.refetch() }} /> : revenueQuery.data && revenueQuery.data.content.length ? <>
          <div className="overflow-x-auto"><table className="w-full min-w-[1080px] text-left text-sm"><thead className="border-b border-border bg-muted/30 text-xs text-muted-foreground"><tr><th className="px-5 py-3 font-medium">Thời gian</th><th className="px-5 py-3 font-medium">Nguồn</th><th className="px-5 py-3 font-medium">Buyer</th><th className="px-5 py-3 font-medium">Amount</th><th className="px-5 py-3 font-medium">Platform fee</th><th className="px-5 py-3 font-medium">Net revenue</th><th className="px-5 py-3 font-medium">Trạng thái</th><th className="px-5 py-3 font-medium">Chi tiết</th></tr></thead><tbody className="divide-y divide-border">{revenueQuery.data.content.map(item => <tr key={item.paymentId} className="align-top"><td className="whitespace-nowrap px-5 py-4 text-muted-foreground">{formatDate(item.paidAt || item.createdAt)}</td><td className="px-5 py-4"><p className="font-medium">{sourceLabel(item.sourceType)}</p><p className="mt-1 max-w-[180px] text-xs text-muted-foreground">{item.sourceLabel}</p></td><td className="px-5 py-4"><p>{display(item.buyerName || item.buyerId)}</p><p className="mt-1 text-xs text-muted-foreground">{display(item.buyerEmail)}</p></td><td className="whitespace-nowrap px-5 py-4 font-medium">{formatMoney(item.amount, item.currency)}</td><td className="whitespace-nowrap px-5 py-4">{formatMoney(item.platformFee, item.currency)}</td><td className="whitespace-nowrap px-5 py-4 font-medium">{formatMoney(item.netRevenue, item.currency)}</td><td className="px-5 py-4"><span className={`badge ${statusClass(item.status)}`}>{statusLabel(item.status)}</span></td><td className="px-5 py-4"><details><summary className="cursor-pointer text-xs text-primary">Xem</summary><dl className="mt-3 min-w-[230px] space-y-1 text-xs"><div><dt className="inline text-muted-foreground">Creator: </dt><dd className="inline">{display(item.creatorChannelName || item.creatorName || item.creatorProfileId || item.creatorUserId)}</dd></div><div><dt className="inline text-muted-foreground">Membership: </dt><dd className="inline">{display(item.membershipPlanName || item.membershipPlanId)}</dd></div><div><dt className="inline text-muted-foreground">Contract: </dt><dd className="inline">{display(item.contractId)}</dd></div><div><dt className="inline text-muted-foreground">Request: </dt><dd className="inline">{display(item.requestTitle || item.requestId)}</dd></div><div><dt className="inline text-muted-foreground">Stage: </dt><dd className="inline">{display(item.stageName || item.stageId)}{item.stageOrder === null ? '' : ` (#${item.stageOrder})`}</dd></div><div><dt className="inline text-muted-foreground">Payment: </dt><dd className="inline">{display(item.paymentMethod)} / {display(item.provider)}</dd></div><div><dt className="inline text-muted-foreground">Transaction: </dt><dd className="inline break-all">{display(item.providerTransactionId)}</dd></div></dl></details></td></tr>)}</tbody></table></div><Pagination page={revenueQuery.data} pending={revenueQuery.isFetching} onPageChange={setRevenuePage} />
        </> : <EmptyState title="Chưa có payment đã thu" message="Backend chưa trả về payment phù hợp với các trạng thái đã thu." />}</section>
      </>
    </>}
  </>
}
