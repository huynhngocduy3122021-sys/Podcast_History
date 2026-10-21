import { Fragment, useRef, useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Eye, Pencil, Plus, RefreshCw } from 'lucide-react'
import { useAuth } from '../auth'
import { api, errorMessage, session } from '../lib/client'
import { extractApiError } from '../lib/api-error'
import { createAdminApi } from '../lib/admin-api'
import { adminKeys, planChangeConfirmed } from '../lib/admin-cache'
import { planWriteSchema, uuidFilterSchema } from '../lib/admin-contracts'
import type { MembershipPlan, PlanWrite } from '../lib/admin-contracts'
import { phase4SuccessMessages } from '../lib/success-feedback'
import { Button } from '../components/ui/button'
import { ConfirmDialog } from '../components/ui/confirm-dialog'
import { EmptyState, ErrorState, LoadingState } from '../components/states'
import { useFeedback } from '../components/feedback'
import { identityOf, sameIdentity } from '../lib/identity'

const backend = createAdminApi(api)
const sessionChangedMessage = 'Phiên đăng nhập đã thay đổi. Vui lòng tải lại dữ liệu trước khi tiếp tục.'

function PlanForm({ plan, onClose }: { plan?: MembershipPlan; onClose: () => void }) {
  const client = useQueryClient()
  const notify = useFeedback()
  const initiatingIdentity = useRef<ReturnType<typeof identityOf>>(null)
  const form = useForm({
    resolver: zodResolver(planWriteSchema),
    defaultValues: { creatorId: plan?.creatorId || '', name: plan?.name || '', description: plan?.description || '', price: plan?.price || '0.01', currency: plan?.currency || 'VND', durationDays: plan?.durationDays || 30, status: plan?.status || 'ACTIVE' } as PlanWrite,
  })
  const mutation = useMutation({
    mutationFn: (values: PlanWrite) => {
      const expected = initiatingIdentity.current
      if (!expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      return backend.savePlan(plan?.planId, values)
    },
    onSuccess: async data => {
      const expected = initiatingIdentity.current
      if (!expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      await planChangeConfirmed(client, expected.id, data.planId)
      if (!sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      notify(plan ? phase4SuccessMessages.planUpdated : phase4SuccessMessages.planCreated)
      onClose()
    },
    onError: async error => {
      const expected = initiatingIdentity.current
      if (extractApiError(error).outcomeUnknown && expected && expected.role === 'ADMIN' && sameIdentity(expected, identityOf(session.getUser()))) await planChangeConfirmed(client, expected.id, plan?.planId)
    },
  })
  const submit = form.handleSubmit(values => { initiatingIdentity.current = identityOf(session.getUser()); mutation.reset(); void mutation.mutateAsync(values).catch(() => undefined) })
  return <section className="panel mb-6"><div className="panel-heading"><div><h2 className="font-semibold">{plan ? `Chỉnh sửa: ${plan.name}` : 'Tạo gói thành viên'}</h2><p className="mt-1 text-xs text-muted-foreground">Giá gửi dạng chuỗi thập phân để giữ chính xác; Backend dùng BigDecimal.</p></div></div><form onSubmit={submit} noValidate className="p-6"><fieldset disabled={mutation.isPending} className="grid gap-5 sm:grid-cols-2"><div><label className="field-label" htmlFor="plan-creator">Creator profile ID *</label><input id="plan-creator" className="field font-mono text-xs" placeholder="UUID của ProducerProfile" {...form.register('creatorId')} />{form.formState.errors.creatorId && <p className="field-error">{form.formState.errors.creatorId.message}</p>}</div><div><label className="field-label" htmlFor="plan-name">Tên gói *</label><input id="plan-name" className="field" maxLength={150} {...form.register('name')} />{form.formState.errors.name && <p className="field-error">{form.formState.errors.name.message}</p>}</div><div><label className="field-label" htmlFor="plan-price">Giá *</label><input id="plan-price" className="field" inputMode="decimal" placeholder="50000.00" {...form.register('price')} />{form.formState.errors.price && <p className="field-error">{form.formState.errors.price.message}</p>}</div><div><label className="field-label" htmlFor="plan-currency">Tiền tệ *</label><input id="plan-currency" className="field uppercase" maxLength={3} {...form.register('currency')} />{form.formState.errors.currency && <p className="field-error">{form.formState.errors.currency.message}</p>}</div><div><label className="field-label" htmlFor="plan-duration">Thời hạn (ngày) *</label><input id="plan-duration" type="number" min={1} max={3650} className="field" {...form.register('durationDays', { valueAsNumber: true })} />{form.formState.errors.durationDays && <p className="field-error">{form.formState.errors.durationDays.message}</p>}</div><div><label className="field-label" htmlFor="plan-status">Trạng thái *</label><select id="plan-status" className="field" {...form.register('status')}><option value="ACTIVE">ACTIVE</option><option value="INACTIVE">INACTIVE</option></select>{form.formState.errors.status && <p className="field-error">{form.formState.errors.status.message}</p>}</div><div className="sm:col-span-2"><label className="field-label" htmlFor="plan-description">Mô tả</label><textarea id="plan-description" className="field py-3" rows={4} maxLength={10000} {...form.register('description')} />{form.formState.errors.description && <p className="field-error">{form.formState.errors.description.message}</p>}</div></fieldset>{mutation.isError && <p role="alert" className="mt-5 rounded-lg bg-destructive/10 p-3 text-sm text-destructive">{errorMessage(mutation.error)}</p>}<div className="mt-6 flex justify-end gap-3"><Button variant="outline" onClick={onClose} disabled={mutation.isPending}>Hủy</Button><Button type="submit" disabled={mutation.isPending}>{mutation.isPending ? 'Đang lưu…' : plan ? 'Lưu thay đổi' : 'Tạo gói'}</Button></div></form></section>
}

function DeactivatePlan({ plan, disabled, onDone }: { plan: MembershipPlan; disabled: boolean; onDone: () => void }) {
  const client = useQueryClient()
  const notify = useFeedback()
  const initiatingIdentity = useRef<ReturnType<typeof identityOf>>(null)
  const [note, setNote] = useState('')
  const mutation = useMutation({
    mutationFn: () => {
      const expected = initiatingIdentity.current
      if (!expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      return backend.deactivatePlan(plan.planId, { note })
    },
    onSuccess: async () => {
      const expected = initiatingIdentity.current
      if (!expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      await planChangeConfirmed(client, expected.id, plan.planId)
      if (!sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      notify(phase4SuccessMessages.planDeactivated)
      onDone()
    },
    onError: async error => {
      const expected = initiatingIdentity.current
      if (extractApiError(error).outcomeUnknown && expected && expected.role === 'ADMIN' && sameIdentity(expected, identityOf(session.getUser()))) await planChangeConfirmed(client, expected.id, plan.planId)
    },
  })
  return <ConfirmDialog trigger={<Button variant="outline" disabled={disabled || plan.status !== 'ACTIVE' || mutation.isPending}>Tắt gói</Button>} title="Tắt gói thành viên?" description="Gói sẽ chuyển INACTIVE và subscription hiện có không bị hủy theo contract Backend." confirmLabel="Xác nhận tắt gói" destructive confirmDisabled={!note.trim()} onOpenChange={open => { initiatingIdentity.current = open ? identityOf(session.getUser()) : null; if (!open) setNote('') }} onConfirm={async () => { await mutation.mutateAsync(); setNote('') }}>
    <label className="field-label" htmlFor="plan-deactivate-note">Ghi chú bắt buộc</label><textarea id="plan-deactivate-note" className="field py-3" rows={4} maxLength={5000} value={note} onChange={event => setNote(event.target.value)} placeholder="Lý do tắt gói" />
  </ConfirmDialog>
}

function PlanDetail({ planId, onEdit, onClose }: { planId: string; onEdit: (plan: MembershipPlan) => void; onClose: () => void }) {
  const { user } = useAuth()
  const query = useQuery({ queryKey: adminKeys.planDetail(user?.id, planId), enabled: user?.role === 'ADMIN', queryFn: ({ signal }) => backend.plan(planId, signal) })
  const plan = query.data
  return <section className="panel h-fit"><div className="panel-heading"><div><p className="eyebrow">Chi tiết gói</p><h2 className="mt-1 text-lg font-semibold">{plan?.name || 'Đang tải…'}</h2></div><Button variant="ghost" onClick={onClose}>Đóng</Button></div>{query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : plan ? <div className="space-y-4 p-6 text-sm"><div><p className="text-xs text-muted-foreground">Plan ID</p><p className="mt-1 break-all font-mono text-xs">{plan.planId}</p></div><div><p className="text-xs text-muted-foreground">Creator profile ID</p><p className="mt-1 break-all font-mono text-xs">{plan.creatorId}</p></div><div className="grid grid-cols-2 gap-4"><div><p className="text-xs text-muted-foreground">Giá</p><p className="mt-1 font-semibold">{plan.price} {plan.currency}</p></div><div><p className="text-xs text-muted-foreground">Thời hạn</p><p className="mt-1">{plan.durationDays} ngày</p></div></div><div><p className="text-xs text-muted-foreground">Trạng thái</p><p className="mt-1"><span className="badge">{plan.status}</span></p></div><div><p className="text-xs text-muted-foreground">Mô tả</p><p className="mt-1 whitespace-pre-wrap break-words">{plan.description || 'Chưa có mô tả'}</p></div><div className="flex flex-wrap gap-2 pt-2"><Button variant="outline" onClick={() => onEdit(plan)}><Pencil className="size-4" />Sửa gói</Button><DeactivatePlan plan={plan} disabled={false} onDone={onClose} /></div></div> : <EmptyState title="Không tìm thấy gói" message="Gói có thể đã thay đổi hoặc không còn tồn tại." />}</section>
}

export function MembershipPlansPage() {
  const { user } = useAuth()
  const [creatorId, setCreatorId] = useState('')
  const [status, setStatus] = useState<'' | 'ACTIVE' | 'INACTIVE'>('')
  const [page, setPage] = useState(0)
  const [selected, setSelected] = useState<string | null>(null)
  const [editor, setEditor] = useState<MembershipPlan | 'new' | null>(null)
  const size = 20
  const creatorIdValid = uuidFilterSchema.safeParse(creatorId).success
  const query = useQuery({ queryKey: adminKeys.planList(user?.id, creatorId, status, page, size), enabled: user?.role === 'ADMIN' && creatorIdValid, queryFn: ({ signal }) => backend.plans({ creatorId, status, page, size }, signal) })
  return <><div className="mb-7 flex flex-wrap items-end justify-between gap-4"><div><p className="eyebrow">Quản lý gói</p><h1 className="mt-2 text-3xl font-bold">Membership Plans</h1><p className="mt-2 text-sm text-muted-foreground">Quản lý gói theo giá, tiền tệ, thời hạn và trạng thái mà Backend hỗ trợ.</p></div><div className="flex gap-3"><Button variant="outline" disabled={query.isFetching || !creatorIdValid} onClick={() => { void query.refetch() }}><RefreshCw className="size-4" />Làm mới</Button><Button disabled={editor !== null} onClick={() => setEditor('new')}><Plus className="size-4" />Tạo gói</Button></div></div>{editor !== null && <PlanForm key={editor === 'new' ? 'new' : editor.planId} plan={editor === 'new' ? undefined : editor} onClose={() => setEditor(null)} />}<section className="panel mb-6"><div className="grid gap-3 p-5 md:grid-cols-[minmax(0,1fr)_180px]"><label><span className="sr-only">Lọc Creator profile ID</span><input className="field font-mono text-xs" value={creatorId} onChange={event => { setCreatorId(event.target.value); setPage(0) }} placeholder="Creator profile ID (UUID)" />{!creatorIdValid && <p role="alert" className="field-error">Creator profile ID phải là UUID hợp lệ.</p>}</label><label><span className="sr-only">Lọc trạng thái gói</span><select className="field" value={status} onChange={event => { setStatus(event.target.value as '' | 'ACTIVE' | 'INACTIVE'); setPage(0) }}><option value="">Mọi trạng thái</option><option value="ACTIVE">ACTIVE</option><option value="INACTIVE">INACTIVE</option></select></label></div></section><section className="panel"><div className="panel-heading"><div><h2 className="font-semibold">Danh sách gói</h2><p className="mt-1 text-xs text-muted-foreground">{query.data ? `${query.data.totalElements} gói · trang ${query.data.number + 1}/${Math.max(1, query.data.totalPages)}` : 'Phân trang từ Backend'}</p></div></div>{!creatorIdValid ? <EmptyState title="Bộ lọc chưa hợp lệ" message="Nhập đủ Creator profile UUID hoặc xóa bộ lọc để tải danh sách." /> : query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : query.data?.content.length ? <><div className="overflow-x-auto"><table className="data-table"><thead><tr><th>Gói</th><th>Giá</th><th>Thời hạn</th><th>Trạng thái</th><th><span className="sr-only">Thao tác</span></th></tr></thead><tbody>{query.data.content.map(plan => <Fragment key={plan.planId}><tr className={selected === plan.planId ? 'bg-muted/40' : ''}><td><p className="font-semibold">{plan.name}</p><p className="mt-1 break-all font-mono text-[11px] text-muted-foreground">{plan.creatorId}</p></td><td className="whitespace-nowrap">{plan.price} {plan.currency}</td><td>{plan.durationDays} ngày</td><td><span className={`badge ${plan.status === 'ACTIVE' ? 'bg-success/10 text-success' : ''}`}>{plan.status}</span></td><td><div className="flex justify-end gap-2"><Button variant="outline" onClick={() => setSelected(plan.planId)}><Eye className="size-4" />Chi tiết</Button><Button variant="outline" disabled={editor !== null} onClick={() => setEditor(plan)}><Pencil className="size-4" />Sửa</Button></div></td></tr>{selected === plan.planId && <tr><td colSpan={5} className="p-0"><PlanDetail planId={selected} onEdit={plan => setEditor(plan)} onClose={() => setSelected(null)} /></td></tr>}</Fragment>)}</tbody></table></div><div className="flex items-center justify-between border-t border-border/60 px-5 py-4 text-sm"><Button variant="outline" disabled={page === 0} onClick={() => setPage(page - 1)}>Trước</Button><span className="text-muted-foreground">Trang {page + 1}/{Math.max(1, query.data.totalPages)}</span><Button variant="outline" disabled={page + 1 >= query.data.totalPages} onClick={() => setPage(page + 1)}>Sau</Button></div></> : <EmptyState title="Chưa có gói thành viên" message="Tạo gói đầu tiên cho một Creator profile đã được Backend phê duyệt." />}</section></>
}
