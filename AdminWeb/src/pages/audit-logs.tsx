import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Activity, RefreshCw } from 'lucide-react'
import { useAuth } from '../auth'
import { api, errorMessage } from '../lib/client'
import { createAdminApi } from '../lib/admin-api'
import { adminKeys } from '../lib/admin-cache'
import { uuidFilterSchema } from '../lib/admin-contracts'
import { Button } from '../components/ui/button'
import { EmptyState, ErrorState, LoadingState } from '../components/states'

const backend = createAdminApi(api)
const date = (value: string) => new Date(value).toLocaleString('vi-VN')

export function AuditLogsPage() {
  const { user } = useAuth()
  const [resourceType, setResourceType] = useState('')
  const [resourceId, setResourceId] = useState('')
  const [page, setPage] = useState(0)
  const size = 20
  const resourceIdValid = uuidFilterSchema.safeParse(resourceId).success
  const query = useQuery({
    queryKey: adminKeys.auditList(user?.id, resourceType, resourceId, page, size),
    enabled: user?.role === 'ADMIN' && resourceIdValid,
    queryFn: ({ signal }) => backend.auditLogs({ resourceType, resourceId, page, size }, signal),
  })
  return <><div className="mb-7 flex flex-wrap items-end justify-between gap-4"><div><p className="eyebrow">Hệ thống</p><h1 className="mt-2 text-3xl font-bold">Nhật ký quản trị</h1><p className="mt-2 text-sm text-muted-foreground">Nhật ký chỉ đọc từ Backend; dữ liệu hiển thị đúng actor, action, target, ghi chú và thời điểm.</p></div><Button variant="outline" disabled={query.isFetching || !resourceIdValid} onClick={() => { void query.refetch() }}><RefreshCw className={`size-4 ${query.isFetching ? 'motion-safe:animate-spin' : ''}`} />Làm mới</Button></div><section className="panel mb-6"><div className="grid gap-3 p-5 md:grid-cols-[180px_minmax(0,1fr)]"><label><span className="sr-only">Lọc loại tài nguyên</span><input className="field" value={resourceType} onChange={event => { setResourceType(event.target.value); setPage(0) }} placeholder="Resource type, ví dụ USER" /></label><label><span className="sr-only">Lọc ID tài nguyên</span><input className="field font-mono text-xs" value={resourceId} onChange={event => { setResourceId(event.target.value); setPage(0) }} placeholder="Resource ID (UUID)" />{!resourceIdValid && <p role="alert" className="field-error">Resource ID phải là UUID hợp lệ.</p>}</label></div></section><section className="panel"><div className="panel-heading"><div><h2 className="flex items-center gap-2 font-semibold"><Activity className="size-4 text-bronze" />Hoạt động gần đây</h2><p className="mt-1 text-xs text-muted-foreground">{query.data ? `${query.data.totalElements} bản ghi · trang ${query.data.number + 1}/${Math.max(1, query.data.totalPages)}` : 'Phân trang từ Backend'}</p></div></div>{!resourceIdValid ? <EmptyState title="Bộ lọc chưa hợp lệ" message="Nhập UUID đầy đủ hoặc xóa bộ lọc để tải audit log." /> : query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : query.data?.content.length ? <><div className="overflow-x-auto"><table className="data-table"><thead><tr><th>Thời điểm</th><th>Actor</th><th>Hành động</th><th>Target</th><th>Ghi chú</th></tr></thead><tbody>{query.data.content.map(item => <tr key={item.auditId}><td className="whitespace-nowrap text-xs">{date(item.createdAt)}</td><td className="max-w-44 break-all font-mono text-[11px]">{item.actorId}</td><td><span className="badge">{item.action}</span></td><td className="max-w-52"><p className="font-semibold">{item.resourceType}</p><p className="mt-1 break-all font-mono text-[11px] text-muted-foreground">{item.resourceId}</p></td><td className="max-w-md whitespace-pre-wrap break-words text-sm">{item.note || '—'}</td></tr>)}</tbody></table></div><div className="flex items-center justify-between border-t border-border/60 px-5 py-4 text-sm"><Button variant="outline" disabled={page === 0} onClick={() => setPage(page - 1)}>Trước</Button><span className="text-muted-foreground">Trang {page + 1}/{Math.max(1, query.data.totalPages)}</span><Button variant="outline" disabled={page + 1 >= query.data.totalPages} onClick={() => setPage(page + 1)}>Sau</Button></div></> : <EmptyState title="Chưa có audit log" message="Không có bản ghi phù hợp với bộ lọc hiện tại." />}</section><p className="mt-4 text-xs text-muted-foreground">Audit log không có endpoint chi tiết, chỉnh sửa hoặc xóa theo Backend contract.</p></>
}
