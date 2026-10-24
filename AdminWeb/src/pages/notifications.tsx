import { Bell, Check } from 'lucide-react'
import { useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { useAuth } from '../auth'
import { errorMessage } from '../lib/client'
import { notificationKeys, createNotificationApi } from '../lib/notifications'
import { useNotificationRead } from '../lib/notification-state'
import { api } from '../lib/client'
import { Button } from '../components/ui/button'
import { EmptyState, ErrorState, LoadingState } from '../components/states'
import { Pagination } from '../components/pagination'

const backend = createNotificationApi(api)
const size = 20
const dateFormat = new Intl.DateTimeFormat('vi-VN', { dateStyle: 'medium', timeStyle: 'short' })
function displayDate(value: string | null) {
  if (!value) return ''
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? '' : dateFormat.format(date)
}

export function NotificationsPage() {
  const { user } = useAuth()
  const [page, setPage] = useState(0)
  const query = useQuery({
    queryKey: user ? notificationKeys.page(user.id, page, size) : ['notifications', 'anonymous', 'page', page, size],
    enabled: !!user,
    queryFn: ({ signal }) => backend.list(page, size, signal),
  })
  const read = useNotificationRead()
  const data = query.data
  return <>
    <div className="mb-7 flex flex-wrap items-end justify-between gap-4"><div><p className="eyebrow">Hệ thống / {user?.role}</p><h1 className="mt-2 text-3xl font-bold">Thông báo</h1><p className="mt-2 text-sm text-muted-foreground">Các cập nhật dành riêng cho tài khoản đang đăng nhập.</p></div><Button variant="outline" disabled={query.isFetching} onClick={() => { void query.refetch() }}>Làm mới</Button></div>
    <section className="panel">
      <div className="panel-heading"><div><h2 className="font-semibold">Thông báo của tôi</h2><p className="mt-1 text-xs text-muted-foreground">{data ? `${data.totalElements} thông báo` : 'Dữ liệu từ Backend'}</p></div><Bell className="size-5 text-muted-foreground" /></div>
      {query.isPending ? <LoadingState message="Đang tải thông báo…" /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : !data?.content.length ? <EmptyState title="Chưa có thông báo" message="Thông báo mới của bạn sẽ xuất hiện tại đây." /> : <>
        <ul className="divide-y divide-border/60">
          {data.content.map(item => <li key={item.notificationId} className={`px-6 py-5 ${item.read ? '' : 'bg-primary/4'}`}>
            <div className="flex items-start gap-4"><span className={`mt-2 size-2 shrink-0 rounded-full ${item.read ? 'bg-border' : 'bg-primary'}`} aria-hidden="true" /><div className="min-w-0 flex-1"><div className="flex flex-wrap items-start justify-between gap-3"><h3 className={`break-words text-sm ${item.read ? 'font-medium' : 'font-semibold'}`}>{item.title || 'Thông báo mới'}</h3>{!item.read && <span className="badge bg-primary/10 text-primary">Chưa đọc</span>}</div>{item.message && <p className="mt-2 whitespace-pre-wrap break-words text-sm leading-6 text-muted-foreground">{item.message}</p>}{item.createdAt && displayDate(item.createdAt) && <time className="mt-3 block text-xs text-muted-foreground" dateTime={item.createdAt}>{displayDate(item.createdAt)}</time>}{!item.read && <Button variant="ghost" className="mt-2 min-h-0 px-0 py-1 text-xs text-primary" disabled={read.isPending} onClick={() => { void read.markRead(item.notificationId).catch(() => undefined) }}><Check className="size-3.5" />Đánh dấu đã đọc</Button>}</div></div>
          </li>)}
        </ul>
        {read.error && <p role="alert" className="border-t border-border px-6 py-4 text-sm text-destructive">{errorMessage(read.error)}</p>}
        <Pagination page={data} pending={query.isFetching || read.isPending} onPageChange={setPage} />
      </>}
    </section>
  </>
}
