import { Fragment, useState } from 'react'
import { useRef } from 'react'
import type { ReactNode } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { RefreshCw, Search, ShieldCheck, UserRound, UserRoundCog } from 'lucide-react'
import { useAuth } from '../auth'
import { api, errorMessage, session } from '../lib/client'
import { extractApiError } from '../lib/api-error'
import { createAdminApi } from '../lib/admin-api'
import { adminKeys, userChangeConfirmed } from '../lib/admin-cache'
import { userProfileSchema } from '../lib/admin-contracts'
import type { AdminUser, AdminUserRole } from '../lib/admin-contracts'
import { phase4SuccessMessages } from '../lib/success-feedback'
import { identityOf, sameIdentity } from '../lib/identity'
import type { SessionIdentity } from '../lib/identity'
import { Button } from '../components/ui/button'
import { ConfirmDialog } from '../components/ui/confirm-dialog'
import { EmptyState, ErrorState, LoadingState } from '../components/states'
import { useFeedback } from '../components/feedback'

const backend = createAdminApi(api)
const roles: AdminUserRole[] = ['LISTENER', 'CREATOR', 'STAFF']
const date = (value: string | null) => value ? new Date(value).toLocaleString('vi-VN') : 'Chưa ghi nhận'
function UserProfileEditor({ user, onDone }: { user: AdminUser; onDone: () => void }) {
  const queryClient = useQueryClient()
  const notify = useFeedback()
  const initiatingIdentity = useRef<SessionIdentity | null>(null)
  const form = useForm({
    resolver: zodResolver(userProfileSchema),
    defaultValues: { displayName: user.displayName, avatarUrl: user.avatarUrl || '', bio: user.bio || '' },
  })
  const mutation = useMutation({
    mutationFn: (values: unknown) => backend.updateUser(user.userId, values),
    onSuccess: async () => {
      const expected = initiatingIdentity.current
      if (!sameIdentity(expected, identityOf(session.getUser()))) return
      await userChangeConfirmed(queryClient, expected?.id, user.userId)
      if (!sameIdentity(expected, identityOf(session.getUser()))) return
      notify(phase4SuccessMessages.userUpdated)
      onDone()
    },
    onError: async error => {
      const expected = initiatingIdentity.current
      if (extractApiError(error).outcomeUnknown && sameIdentity(expected, identityOf(session.getUser()))) await userChangeConfirmed(queryClient, expected?.id, user.userId)
    },
  })
  const submit = form.handleSubmit(values => {
    const expected = identityOf(session.getUser())
    if (!expected) return
    initiatingIdentity.current = expected
    mutation.reset()
    void mutation.mutateAsync(values).catch(() => undefined)
  })
  return <form onSubmit={submit} noValidate className="mt-5 rounded-xl border border-border bg-muted/20 p-4">
    <fieldset disabled={mutation.isPending} className="grid gap-4 sm:grid-cols-2">
      <div><label className="field-label" htmlFor="user-display-name">Tên hiển thị *</label><input id="user-display-name" className="field" maxLength={120} {...form.register('displayName')} />{form.formState.errors.displayName && <p className="field-error">{form.formState.errors.displayName.message}</p>}</div>
      <div><label className="field-label" htmlFor="user-avatar-url">URL ảnh đại diện</label><input id="user-avatar-url" className="field" maxLength={2000} {...form.register('avatarUrl')} />{form.formState.errors.avatarUrl && <p className="field-error">{form.formState.errors.avatarUrl.message}</p>}</div>
      <div className="sm:col-span-2"><label className="field-label" htmlFor="user-bio">Tiểu sử</label><textarea id="user-bio" className="field py-3" rows={4} maxLength={5000} {...form.register('bio')} />{form.formState.errors.bio && <p className="field-error">{form.formState.errors.bio.message}</p>}</div>
    </fieldset>
    {mutation.isError && <p role="alert" className="mt-4 rounded-lg bg-destructive/10 p-3 text-sm text-destructive">{errorMessage(mutation.error)}</p>}
    <div className="mt-4 flex justify-end gap-3"><Button variant="outline" onClick={onDone} disabled={mutation.isPending}>Hủy</Button><Button type="submit" disabled={mutation.isPending}>{mutation.isPending ? 'Đang lưu…' : 'Lưu hồ sơ'}</Button></div>
  </form>
}

function NoteAction({ label, title, description, destructive = false, onConfirm, disabled = false, extra }: { label: string; title: string; description: string; destructive?: boolean; onConfirm: (note: string) => Promise<void>; disabled?: boolean; extra?: ReactNode }) {
  const [note, setNote] = useState('')
  return <ConfirmDialog trigger={<Button variant={destructive ? 'destructive' : 'outline'} disabled={disabled}>{label}</Button>} title={title} description={description} confirmLabel="Xác nhận" destructive={destructive} confirmDisabled={!note.trim()} onOpenChange={open => { if (!open) setNote('') }} onConfirm={() => onConfirm(note)}>
    <label className="field-label" htmlFor={`action-note-${label}`}>Ghi chú bắt buộc</label><textarea id={`action-note-${label}`} className="field py-3" rows={4} maxLength={5000} value={note} onChange={event => setNote(event.target.value)} placeholder="Nêu lý do để lưu audit log" />
    {extra}
  </ConfirmDialog>
}

function UserSecurityActions({ user }: { user: AdminUser }) {
  const client = useQueryClient()
  const notify = useFeedback()
  const initiatingIdentity = useRef<SessionIdentity | null>(null)
  const [targetRole, setTargetRole] = useState<AdminUserRole>(user.role === 'CREATOR' ? 'STAFF' : 'CREATOR')
  const useUserAction = (kind: 'access' | 'verification' | 'role' | 'revoke') => useMutation({
    mutationFn: (values: { note: string; role?: AdminUserRole }) => kind === 'access'
      ? backend.changeAccess(user.userId, { active: !user.active, note: values.note })
      : kind === 'verification'
        ? backend.changeVerification(user.userId, { verified: !user.verified, note: values.note })
        : kind === 'revoke'
          ? backend.revokeSessions(user.userId, { note: values.note })
          : backend.changeRole(user.userId, { role: values.role || 'LISTENER', note: values.note }),
    onSuccess: async () => {
      const expected = initiatingIdentity.current
      if (!sameIdentity(expected, identityOf(session.getUser()))) return
      await userChangeConfirmed(client, expected?.id, user.userId)
      if (!sameIdentity(expected, identityOf(session.getUser()))) return
      const currentTarget = user.userId === expected?.id
      if (kind === 'access') notify(phase4SuccessMessages.userAccessChanged)
      if (kind === 'verification') notify(phase4SuccessMessages.userVerificationChanged)
      if (kind === 'role') notify(phase4SuccessMessages.userRoleChanged)
      if (kind === 'revoke') notify(currentTarget ? 'Đã thu hồi phiên hiện tại. Bạn sẽ được đưa về trang đăng nhập.' : phase4SuccessMessages.sessionsRevoked)
      if (currentTarget && (kind === 'revoke')) await session.logout().catch(() => undefined)
    },
    onError: async error => {
      const expected = initiatingIdentity.current
      if (extractApiError(error).outcomeUnknown && sameIdentity(expected, identityOf(session.getUser()))) await userChangeConfirmed(client, expected?.id, user.userId)
    },
  })
  const access = useUserAction('access')
  const verification = useUserAction('verification')
  const role = useUserAction('role')
  const revoke = useUserAction('revoke')
  const busy = access.isPending || verification.isPending || role.isPending || revoke.isPending
  const begin = async (mutation: { mutateAsync: (values: { note: string; role?: AdminUserRole }) => Promise<unknown> }, values: { note: string; role?: AdminUserRole }) => {
    const expected = identityOf(session.getUser())
    if (!expected) throw new Error('Phiên đăng nhập đã thay đổi. Vui lòng đăng nhập lại.')
    initiatingIdentity.current = expected
    await mutation.mutateAsync(values)
  }
  return <div className="mt-6 border-t border-border/60 pt-5"><div className="mb-3 flex items-center gap-2"><ShieldCheck className="size-4 text-bronze" /><h3 className="font-semibold">Thao tác bảo mật</h3></div><p className="mb-4 text-xs leading-5 text-muted-foreground">Khóa/mở tài khoản, đổi vai trò hoặc thu hồi phiên sẽ có hiệu lực ở Backend và làm token cũ không còn hợp lệ.</p><div className="flex flex-wrap gap-2">
    {user.role !== 'ADMIN' && <NoteAction label={user.active ? 'Khóa tài khoản' : 'Mở khóa tài khoản'} title={user.active ? 'Khóa tài khoản?' : 'Mở khóa tài khoản?'} description={user.active ? 'Tài khoản sẽ không đăng nhập được và các phiên hiện tại sẽ bị thu hồi.' : 'Tài khoản sẽ được phép đăng nhập lại.'} destructive={user.active} disabled={busy} onConfirm={async note => { await begin(access, { note }) }} />}
    <NoteAction label={user.verified ? 'Bỏ xác minh' : 'Xác minh tài khoản'} title={user.verified ? 'Bỏ trạng thái xác minh?' : 'Xác minh tài khoản?'} description="Thay đổi này được lưu vào tài khoản và audit log." disabled={busy} onConfirm={async note => { await begin(verification, { note }) }} />
    {user.role !== 'ADMIN' && <NoteAction label="Đổi vai trò" title="Đổi vai trò tài khoản?" description="Đổi vai trò sẽ thu hồi các phiên cũ. Role CREATOR chỉ thành công khi hồ sơ Creator đã được Backend duyệt." disabled={busy} onConfirm={async note => { await begin(role, { note, role: targetRole }) }} extra={<label className="mb-4 block"><span className="field-label">Vai trò mới</span><select className="field" value={targetRole} onChange={event => setTargetRole(event.target.value as AdminUserRole)}>{roles.filter(item => item !== user.role).map(item => <option key={item} value={item}>{item}</option>)}</select></label>} />}
    <NoteAction label="Thu hồi phiên" title="Thu hồi toàn bộ phiên đăng nhập?" description="Mọi access token và refresh token hiện tại của tài khoản sẽ bị thu hồi. Nếu đây là tài khoản của bạn, phiên hiện tại sẽ kết thúc." destructive disabled={busy} onConfirm={async note => { await begin(revoke, { note }) }} />
  </div></div>
}

function UserDetail({ targetId, fallback, onClose }: { targetId: string; fallback?: AdminUser; onClose: () => void }) {
  const { user } = useAuth()
  const [editing, setEditing] = useState(false)
  const query = useQuery({ queryKey: adminKeys.userDetail(user?.id, targetId), enabled: user?.role === 'ADMIN', queryFn: ({ signal }) => backend.user(targetId, signal) })
  const target = query.data || fallback
  return <section className="panel h-fit"><div className="panel-heading"><div><p className="eyebrow">Chi tiết tài khoản</p><h2 className="mt-1 text-lg font-semibold">{target?.displayName || target?.username || 'Đang tải…'}</h2></div><Button variant="ghost" onClick={onClose}>Đóng</Button></div>{query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : target ? <div className="p-6"><div className="grid gap-4 text-sm sm:grid-cols-2"><div><p className="text-xs text-muted-foreground">Username</p><p className="mt-1 font-semibold break-all">{target.username}</p></div><div><p className="text-xs text-muted-foreground">Email</p><p className="mt-1 break-all">{target.email}</p></div><div><p className="text-xs text-muted-foreground">Vai trò</p><p className="mt-1"><span className="badge">{target.role}</span></p></div><div><p className="text-xs text-muted-foreground">Trạng thái</p><p className="mt-1">{target.active ? 'Đang hoạt động' : 'Đã khóa'} · {target.verified ? 'Đã xác minh' : 'Chưa xác minh'}</p></div><div><p className="text-xs text-muted-foreground">Tạo lúc</p><p className="mt-1">{date(target.createdAt)}</p></div><div><p className="text-xs text-muted-foreground">Đăng nhập gần nhất</p><p className="mt-1">{date(target.lastLoginAt)}</p></div><div className="sm:col-span-2"><p className="text-xs text-muted-foreground">Tiểu sử</p><p className="mt-1 whitespace-pre-wrap break-words">{target.bio || 'Chưa có tiểu sử'}</p></div></div><div className="mt-5 flex flex-wrap gap-2"><Button variant="outline" onClick={() => setEditing(value => !value)}><UserRoundCog className="size-4" />{editing ? 'Đóng chỉnh sửa' : 'Sửa hồ sơ'}</Button></div>{editing && <UserProfileEditor key={target.userId} user={target} onDone={() => setEditing(false)} />}<UserSecurityActions user={target} /></div> : <EmptyState title="Không tìm thấy người dùng" message="Tài khoản có thể đã thay đổi hoặc không còn tồn tại." />}</section>
}

export function UsersPage() {
  const { user } = useAuth()
  const [q, setQ] = useState('')
  const [role, setRole] = useState<AdminUserRole | ''>('')
  const [active, setActive] = useState('')
  const [page, setPage] = useState(0)
  const [selected, setSelected] = useState<string | null>(null)
  const size = 20
  const query = useQuery({
    queryKey: adminKeys.userList(user?.id, q, role, active, page, size),
    enabled: user?.role === 'ADMIN',
    queryFn: ({ signal }) => backend.users({ q, role, active: active === '' ? undefined : active === 'true', page, size }, signal),
  })
  const changeFilter = <T,>(setter: (value: T) => void) => (value: T) => { setter(value); setPage(0) }
  return <><div className="mb-7 flex flex-wrap items-end justify-between gap-4"><div><p className="eyebrow">Quản lý tài khoản</p><h1 className="mt-2 text-3xl font-bold">Người dùng</h1><p className="mt-2 text-sm text-muted-foreground">Xem hồ sơ, trạng thái truy cập, xác minh, vai trò và phiên đăng nhập theo contract Backend.</p></div><Button variant="outline" disabled={query.isFetching} onClick={() => { void query.refetch() }}><RefreshCw className={`size-4 ${query.isFetching ? 'motion-safe:animate-spin' : ''}`} />Làm mới</Button></div>
    <section className="panel mb-6"><div className="grid gap-3 p-5 md:grid-cols-[minmax(0,1fr)_180px_180px]"><label className="relative"><span className="sr-only">Tìm người dùng</span><Search className="pointer-events-none absolute top-3.5 left-3 size-4 text-muted-foreground" /><input className="field pl-9" value={q} onChange={event => changeFilter(setQ)(event.target.value)} placeholder="Tìm username, email, tên hiển thị" /></label><label><span className="sr-only">Lọc vai trò</span><select className="field" value={role} onChange={event => changeFilter(setRole)(event.target.value as AdminUserRole | '')}><option value="">Tất cả vai trò</option>{roles.map(item => <option key={item} value={item}>{item}</option>)}</select></label><label><span className="sr-only">Lọc trạng thái</span><select className="field" value={active} onChange={event => changeFilter(setActive)(event.target.value)}><option value="">Mọi trạng thái</option><option value="true">Đang hoạt động</option><option value="false">Đã khóa</option></select></label></div></section>
    <div><section className="panel"><div className="panel-heading"><div><h2 className="font-semibold">Danh sách người dùng</h2><p className="mt-1 text-xs text-muted-foreground">{query.data ? `${query.data.totalElements} tài khoản · trang ${query.data.number + 1}/${Math.max(1, query.data.totalPages)}` : 'Phân trang từ Backend'}</p></div></div>{query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : query.data?.content.length ? <><div className="overflow-x-auto"><table className="data-table"><thead><tr><th>Tài khoản</th><th>Vai trò</th><th>Trạng thái</th><th><span className="sr-only">Xem</span></th></tr></thead><tbody>{query.data.content.map(item => <Fragment key={item.userId}><tr className={selected === item.userId ? 'bg-muted/40' : ''}><td><button className="text-left" onClick={() => setSelected(item.userId)}><p className="font-semibold hover:text-primary">{item.displayName}</p><p className="mt-1 text-xs text-muted-foreground break-all">{item.username} · {item.email}</p></button></td><td><span className="badge">{item.role}</span></td><td><span className={item.active ? 'text-success' : 'text-destructive'}>{item.active ? 'Hoạt động' : 'Đã khóa'}</span><p className="mt-1 text-xs text-muted-foreground">{item.verified ? 'Đã xác minh' : 'Chưa xác minh'}</p></td><td><Button variant="outline" onClick={() => setSelected(item.userId)}><UserRound className="size-4" />Chi tiết</Button></td></tr>{selected === item.userId && <tr><td colSpan={4} className="p-0"><UserDetail targetId={selected} fallback={item} onClose={() => setSelected(null)} /></td></tr>}</Fragment>)}</tbody></table></div><Pagination page={query.data.number} totalPages={query.data.totalPages} onPage={setPage} /></> : <EmptyState title="Không có người dùng" message="Thử điều chỉnh từ khóa hoặc bộ lọc." />}</section></div>
  </>
}

function Pagination({ page, totalPages, onPage }: { page: number; totalPages: number; onPage: (page: number) => void }) {
  if (totalPages <= 1) return null
  return <div className="flex items-center justify-between border-t border-border/60 px-5 py-4 text-sm"><Button variant="outline" disabled={page === 0} onClick={() => onPage(page - 1)}>Trước</Button><span className="text-muted-foreground">Trang {page + 1}/{totalPages}</span><Button variant="outline" disabled={page + 1 >= totalPages} onClick={() => onPage(page + 1)}>Sau</Button></div>
}
