import { useQuery } from '@tanstack/react-query'
import { ArrowRight, RefreshCw, Users, Mic, ShieldCheck, UserCheck } from 'lucide-react'
import { Link } from 'react-router-dom'
import { useAuth } from '../auth'
import { api, errorMessage } from '../lib/client'
import { dashboardSchema } from '../lib/contracts'
import { formatMoney } from '../lib/finance-format'
import { apiPrefix, isRole } from '../lib/permissions'
import { Button } from '../components/ui/button'
import { EmptyState, ErrorState, LoadingState } from '../components/states'

const number = new Intl.NumberFormat('vi-VN')
export function DashboardPage() {
  const { user } = useAuth()
  const role = user?.role
  const query = useQuery({
    queryKey: ['dashboard', user?.id, role],
    enabled: isRole(role),
    queryFn: async ({ signal }) => {
      if (!isRole(role)) throw new Error('Vai trò không hợp lệ.')
      return dashboardSchema.parse((await api.get(`${apiPrefix(role)}/dashboard`, { signal })).data)
    },
  })
  const data = query.data
  const admin = role === 'ADMIN'
  const metrics = data ? [
    { label: 'Người dùng', value: data.users, detail: `${number.format(data.activeUsers)} đang hoạt động`, icon: Users },
    { label: 'Creator đã duyệt', value: data.creators, detail: admin ? `${number.format(data.pendingCreators)} hồ sơ chờ duyệt` : 'Kênh đã được phê duyệt', icon: UserCheck },
    { label: 'Podcast', value: data.podcasts, detail: `${number.format(data.pendingPodcasts)} chờ kiểm duyệt`, icon: Mic },
    { label: 'Báo cáo đang mở', value: data.pendingReports, detail: 'Chờ xử lý hoặc đang xem xét', icon: ShieldCheck },
  ] : []
  return <>
    <div className="mb-8 flex flex-wrap items-end justify-between gap-4"><div><p className="eyebrow">Không gian làm việc / {role}</p><h1 className="mt-2 text-3xl font-bold tracking-tight">Tổng quan vận hành</h1><p className="mt-2 text-sm text-muted-foreground">Theo dõi nội dung và các công việc cần xử lý.</p></div><Button variant="outline" disabled={query.isFetching} onClick={() => { void query.refetch() }}><RefreshCw className={`size-4 ${query.isFetching ? 'motion-safe:animate-spin' : ''}`} />Làm mới</Button></div>
    {query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : data && <>
      <div className="mb-8 flex items-center gap-2 text-xs text-muted-foreground"><span className="size-1.5 rounded-full bg-success" />Dữ liệu từ Backend · cập nhật {new Date(query.dataUpdatedAt).toLocaleTimeString('vi-VN')}</div>
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{metrics.map(m => <section key={m.label} className="panel p-5"><div className="flex items-center justify-between"><h2 className="text-sm font-medium text-muted-foreground">{m.label}</h2><m.icon className="size-5 text-bronze" aria-hidden="true" /></div><p className="mt-5 text-4xl font-semibold tracking-tight">{number.format(m.value)}</p><p className="mt-3 text-xs text-muted-foreground">{m.detail}</p></section>)}</div>
      <div className="mt-6 grid gap-6 xl:grid-cols-[1.4fr_1fr]"><section className="panel"><div className="panel-heading"><div><h2 className="font-semibold">Trạng thái nội dung</h2><p className="mt-1 text-xs text-muted-foreground">Phân bố podcast theo trạng thái Backend</p></div><Mic className="size-5 text-muted-foreground" /></div>{data.podcastStatuses.length ? <div className="space-y-5 p-6">{data.podcastStatuses.map((s, i) => <div key={`${s.status}-${i}`}><div className="mb-2 flex justify-between gap-3 text-sm"><span>{s.status || 'Chưa có trạng thái'}</span><span className="font-semibold">{number.format(s.count)}</span></div><div className="h-2 overflow-hidden rounded-full bg-muted"><div className="h-full rounded-full bg-primary/80" style={{ width: `${data.podcasts ? Math.min(100, s.count / data.podcasts * 100) : 0}%` }} /></div></div>)}</div> : <EmptyState title="Chưa có podcast" message="Trạng thái sẽ xuất hiện khi Backend có dữ liệu." />}</section>
      <section className="panel"><div className="panel-heading"><h2 className="font-semibold">Cần chú ý</h2><span className="badge">Hàng đợi</span></div><div className="divide-y divide-border px-6">{[
        { label: 'Podcast chờ kiểm duyệt', count: data.pendingPodcasts, path: '/podcast-moderation' },
        { label: 'Báo cáo chưa kết thúc', count: data.pendingReports, path: '/reports' },
        ...(admin ? [{ label: 'Hồ sơ Creator', count: data.pendingCreators, path: '/creator-approval' }, { label: 'Yêu cầu rút tiền', count: data.pendingWithdrawals, path: '/withdrawals' }, { label: 'Tranh chấp đang mở', count: data.openDisputes, path: '/disputes' }] : []),
      ].map(item => <Link to={item.path} key={item.path} className="flex items-center gap-3 py-5 text-sm hover:text-primary"><span className="flex-1">{item.label}</span><span className="font-bold">{number.format(item.count)}</span><ArrowRight className="size-4" /></Link>)}</div><p className="border-t border-border px-6 py-4 text-xs text-muted-foreground">Theo dõi các chỉ số vận hành và hàng đợi cần xử lý theo quyền của tài khoản.</p></section></div>
      {admin && <section className="panel mt-6"><div className="panel-heading"><div><h2 className="font-semibold">Thanh toán đã thu</h2><p className="mt-1 text-xs text-muted-foreground">Theo từng loại tiền tệ</p></div></div>{data.collectedPayments.length ? <div className="flex flex-wrap gap-8 p-6">{data.collectedPayments.map(r => <div key={r.currency}><p className="text-xs text-muted-foreground">{r.currency}</p><p className="mt-1 text-2xl font-semibold">{formatMoney(r.amount, r.currency)}</p></div>)}</div> : <EmptyState title="Chưa có thanh toán đã thu" message="Không sử dụng số liệu mẫu." />}<p className="px-6 pb-5 text-xs text-muted-foreground">Đây là tổng thanh toán đã thu, không phải lợi nhuận hoặc số dư có thể rút. Các currency không được cộng chung.</p></section>}
    </>}
  </>
}
