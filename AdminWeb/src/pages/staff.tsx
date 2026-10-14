import { useState } from 'react'
import { useRef } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { KeyRound, Plus, RefreshCw } from 'lucide-react'
import { useAuth } from '../auth'
import { api, errorMessage, session } from '../lib/client'
import { extractApiError } from '../lib/api-error'
import { createAdminApi } from '../lib/admin-api'
import { adminKeys, staffChangeConfirmed } from '../lib/admin-cache'
import { staffCreateSchema } from '../lib/admin-contracts'
import type { StaffCreate } from '../lib/admin-contracts'
import { phase4SuccessMessages } from '../lib/success-feedback'
import { identityOf, sameIdentity } from '../lib/identity'
import type { SessionIdentity } from '../lib/identity'
import { Button } from '../components/ui/button'
import { EmptyState, ErrorState, LoadingState } from '../components/states'
import { useFeedback } from '../components/feedback'

const backend = createAdminApi(api)
const date = (value: string | null) => value ? new Date(value).toLocaleString('vi-VN') : 'Chưa ghi nhận'

function StaffForm({ onClose }: { onClose: () => void }) {
  const client = useQueryClient()
  const notify = useFeedback()
  const pendingValues = useRef<StaffCreate | null>(null)
  const initiatingIdentity = useRef<SessionIdentity | null>(null)
  const form = useForm({ resolver: zodResolver(staffCreateSchema), defaultValues: { username: '', email: '', password: '', displayName: '' } })
  const mutation = useMutation({
    mutationFn: async () => {
      const values = pendingValues.current
      if (!values) throw new Error('Không có dữ liệu tạo Staff hợp lệ.')
      return backend.createStaff(values)
    },
    onSuccess: async () => {
      pendingValues.current = null
      const expected = initiatingIdentity.current
      if (!expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) return
      await staffChangeConfirmed(client, expected.id)
      if (!sameIdentity(expected, identityOf(session.getUser()))) return
      form.reset({ username: '', email: '', password: '', displayName: '' })
      notify(phase4SuccessMessages.staffCreated)
      onClose()
    },
    onError: async error => {
      pendingValues.current = null
      // A lost response can still have created the account; reload lists before retrying.
      const expected = initiatingIdentity.current
      if (extractApiError(error).outcomeUnknown && expected && sameIdentity(expected, identityOf(session.getUser()))) await staffChangeConfirmed(client, expected.id)
    },
  })
  const submit = form.handleSubmit(values => {
    const expected = identityOf(session.getUser())
    if (!expected || expected.role !== 'ADMIN') return
    initiatingIdentity.current = expected
    pendingValues.current = values
    mutation.reset()
    void mutation.mutateAsync().catch(() => undefined)
  })
  return <section className="panel mb-6"><div className="panel-heading"><div><h2 className="font-semibold">Tạo tài khoản Staff</h2><p className="mt-1 text-xs text-muted-foreground">Mật khẩu chỉ gửi trong request tạo tài khoản, không được lưu vào cache hay hiển thị lại.</p></div></div><form onSubmit={submit} noValidate className="p-6"><fieldset disabled={mutation.isPending} className="grid gap-5 sm:grid-cols-2"><div><label className="field-label" htmlFor="staff-username">Username *</label><input id="staff-username" className="field" autoFocus maxLength={50} {...form.register('username')} />{form.formState.errors.username && <p className="field-error">{form.formState.errors.username.message}</p>}</div><div><label className="field-label" htmlFor="staff-email">Email *</label><input id="staff-email" type="email" className="field" maxLength={255} {...form.register('email')} />{form.formState.errors.email && <p className="field-error">{form.formState.errors.email.message}</p>}</div><div><label className="field-label" htmlFor="staff-display-name">Tên hiển thị *</label><input id="staff-display-name" className="field" maxLength={120} {...form.register('displayName')} />{form.formState.errors.displayName && <p className="field-error">{form.formState.errors.displayName.message}</p>}</div><div><label className="field-label" htmlFor="staff-password">Mật khẩu *</label><input id="staff-password" type="password" autoComplete="new-password" className="field" maxLength={72} {...form.register('password')} />{form.formState.errors.password && <p className="field-error">{form.formState.errors.password.message}</p>}</div></fieldset>{mutation.isError && <p role="alert" className="mt-5 rounded-lg bg-destructive/10 p-3 text-sm text-destructive">{errorMessage(mutation.error)}</p>}<div className="mt-6 flex justify-end gap-3"><Button variant="outline" onClick={onClose} disabled={mutation.isPending}>Hủy</Button><Button type="submit" disabled={mutation.isPending}>{mutation.isPending ? 'Đang tạo…' : 'Tạo Staff'}</Button></div></form></section>
}

export function StaffPage() {
  const { user } = useAuth()
  const [page, setPage] = useState(0)
  const [creating, setCreating] = useState(false)
  const size = 20
  const query = useQuery({ queryKey: adminKeys.staff(user?.id, page, size), enabled: user?.role === 'ADMIN', queryFn: ({ signal }) => backend.staff(page, size, signal) })
  return <><div className="mb-7 flex flex-wrap items-end justify-between gap-4"><div><p className="eyebrow">Quản lý tài khoản</p><h1 className="mt-2 text-3xl font-bold">Nhân viên Staff</h1><p className="mt-2 text-sm text-muted-foreground">Backend hiện chỉ hỗ trợ danh sách và tạo Staff; không có chỉnh sửa, xóa hoặc đặt lại mật khẩu.</p></div><div className="flex gap-3"><Button variant="outline" disabled={query.isFetching} onClick={() => { void query.refetch() }}><RefreshCw className={`size-4 ${query.isFetching ? 'motion-safe:animate-spin' : ''}`} />Làm mới</Button><Button onClick={() => setCreating(value => !value)}><Plus className="size-4" />{creating ? 'Đóng form' : 'Tạo Staff'}</Button></div></div>{creating && <StaffForm onClose={() => setCreating(false)} />}<section className="panel"><div className="panel-heading"><div><h2 className="font-semibold">Danh sách Staff</h2><p className="mt-1 text-xs text-muted-foreground">{query.data ? `${query.data.totalElements} tài khoản · trang ${query.data.number + 1}/${Math.max(1, query.data.totalPages)}` : 'Phân trang từ Backend'}</p></div></div>{query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : query.data?.content.length ? <><div className="overflow-x-auto"><table className="data-table"><thead><tr><th>Nhân viên</th><th>Trạng thái</th><th>Xác minh</th><th>Lần đăng nhập gần nhất</th></tr></thead><tbody>{query.data.content.map(item => <tr key={item.userId}><td><p className="font-semibold">{item.displayName}</p><p className="mt-1 text-xs text-muted-foreground break-all">{item.username} · {item.email}</p></td><td><span className={item.active ? 'text-success' : 'text-destructive'}>{item.active ? 'Hoạt động' : 'Đã khóa'}</span></td><td>{item.verified ? 'Đã xác minh' : 'Chưa xác minh'}</td><td>{date(item.lastLoginAt)}</td></tr>)}</tbody></table></div><div className="flex items-center justify-between border-t border-border/60 px-5 py-4 text-sm"><Button variant="outline" disabled={page === 0} onClick={() => setPage(page - 1)}>Trước</Button><span className="text-muted-foreground">Trang {page + 1}/{Math.max(1, query.data.totalPages)}</span><Button variant="outline" disabled={page + 1 >= query.data.totalPages} onClick={() => setPage(page + 1)}>Sau</Button></div></> : <EmptyState title="Chưa có Staff" message="Tạo tài khoản Staff đầu tiên để phân công vận hành." />}</section><p className="mt-4 flex items-center gap-2 text-xs text-muted-foreground"><KeyRound className="size-4" /> Không có API Backend để sửa, xóa hoặc reset mật khẩu Staff trong phase này.</p></>
}
