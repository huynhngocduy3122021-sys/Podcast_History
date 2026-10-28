import { Fragment, useRef, useState } from 'react'
import { useFieldArray, useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Eye, Pencil, Plus, RefreshCw, Trash2 } from 'lucide-react'
import { useAuth } from '../auth'
import { api, errorMessage, session } from '../lib/client'
import { extractApiError } from '../lib/api-error'
import { createAdminApi } from '../lib/admin-api'
import { adminKeys, creatorSystemPlanChangeConfirmed } from '../lib/admin-cache'
import { creatorSystemPlanWriteSchema } from '../lib/admin-contracts'
import type { CreatorSystemPlan, CreatorSystemPlanWrite } from '../lib/admin-contracts'
import { phase4SuccessMessages } from '../lib/success-feedback'
import { identityOf, sameIdentity } from '../lib/identity'
import { Button } from '../components/ui/button'
import { ConfirmDialog } from '../components/ui/confirm-dialog'
import { EmptyState, ErrorState, LoadingState } from '../components/states'
import { useFeedback } from '../components/feedback'

const backend = createAdminApi(api)
const sessionChangedMessage = 'Phiên đăng nhập đã thay đổi. Vui lòng tải lại dữ liệu trước khi tiếp tục.'

function planStatusLabel(status: string) {
  return status === 'ACTIVE' ? 'Đang hoạt động' : 'Ngừng hoạt động'
}

function PlanForm({ plan, onClose }: { plan?: CreatorSystemPlan; onClose: () => void }) {
  const client = useQueryClient()
  const notify = useFeedback()
  const initiatingIdentity = useRef<ReturnType<typeof identityOf>>(null)
  const form = useForm({
    resolver: zodResolver(creatorSystemPlanWriteSchema),
    defaultValues: {
      code: plan?.code || '', name: plan?.name || '', description: plan?.description || '',
      price: plan?.price || '0', currency: plan?.currency || 'VND',
      durationDays: plan?.durationDays ?? null, status: plan?.status || 'ACTIVE',
      benefits: plan?.benefits.map(item => ({ ...item, description: item.description || '' })) || [],
    },
  })
  const benefits = useFieldArray({ control: form.control, name: 'benefits' })
  const mutation = useMutation({
    mutationFn: (values: CreatorSystemPlanWrite) => {
      const expected = initiatingIdentity.current
      if (!expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      return backend.saveCreatorSystemPlan(plan?.planId, values)
    },
    onSuccess: async data => {
      const expected = initiatingIdentity.current
      if (!expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      await creatorSystemPlanChangeConfirmed(client, expected.id, data.planId)
      if (!sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      notify(plan ? phase4SuccessMessages.creatorSystemPlanUpdated : phase4SuccessMessages.creatorSystemPlanCreated)
      onClose()
    },
    onError: async error => {
      const expected = initiatingIdentity.current
      if (extractApiError(error).outcomeUnknown && expected && expected.role === 'ADMIN' && sameIdentity(expected, identityOf(session.getUser()))) await creatorSystemPlanChangeConfirmed(client, expected.id, plan?.planId)
    },
  })
  const submit = form.handleSubmit(values => { initiatingIdentity.current = identityOf(session.getUser()); mutation.reset(); void mutation.mutateAsync(values).catch(() => undefined) })
  const fieldError = (name: string) => (form.formState.errors as Record<string, { message?: string } | undefined>)[name]?.message
  return <section className="panel mb-6"><div className="panel-heading"><div><h2 className="font-semibold">{plan ? `Chỉnh sửa: ${plan.name}` : 'Tạo gói Premium'}</h2><p className="mt-1 text-xs text-muted-foreground">Quản lý giá, thời hạn và quyền lợi theo contract Backend.</p></div></div><form onSubmit={submit} noValidate className="p-6"><fieldset disabled={mutation.isPending} className="grid gap-5 sm:grid-cols-2"><div><label className="field-label" htmlFor="creator-system-code">Mã gói *</label><input id="creator-system-code" className="field uppercase" maxLength={60} {...form.register('code')} />{fieldError('code') && <p className="field-error">{fieldError('code')}</p>}</div><div><label className="field-label" htmlFor="creator-system-name">Tên gói *</label><input id="creator-system-name" className="field" maxLength={150} {...form.register('name')} />{fieldError('name') && <p className="field-error">{fieldError('name')}</p>}</div><div><label className="field-label" htmlFor="creator-system-price">Giá *</label><input id="creator-system-price" className="field" inputMode="decimal" placeholder="0 hoặc 50000.00" {...form.register('price')} />{fieldError('price') && <p className="field-error">{fieldError('price')}</p>}</div><div><label className="field-label" htmlFor="creator-system-currency">Tiền tệ *</label><input id="creator-system-currency" className="field uppercase" maxLength={3} {...form.register('currency')} />{fieldError('currency') && <p className="field-error">{fieldError('currency')}</p>}</div><div><label className="field-label" htmlFor="creator-system-duration">Thời hạn (ngày)</label><input id="creator-system-duration" type="number" min={1} max={3650} className="field" placeholder="Để trống cho FREE" {...form.register('durationDays')} />{fieldError('durationDays') && <p className="field-error">{fieldError('durationDays')}</p>}</div><div><label className="field-label" htmlFor="creator-system-status">Trạng thái *</label><select id="creator-system-status" className="field" {...form.register('status')}><option value="ACTIVE">Đang hoạt động</option><option value="INACTIVE">Ngừng hoạt động</option></select>{fieldError('status') && <p className="field-error">{fieldError('status')}</p>}</div><div className="sm:col-span-2"><label className="field-label" htmlFor="creator-system-description">Mô tả</label><textarea id="creator-system-description" className="field py-3" rows={3} maxLength={10000} {...form.register('description')} />{fieldError('description') && <p className="field-error">{fieldError('description')}</p>}</div><div className="sm:col-span-2"><div className="mb-3 flex items-center justify-between gap-3"><h3 className="font-semibold">Quyền lợi</h3><Button type="button" variant="outline" onClick={() => benefits.append({ key: '', value: '', description: '' })} disabled={benefits.fields.length >= 30}><Plus className="size-4" />Thêm quyền lợi</Button></div><div className="space-y-4">{benefits.fields.map((field, index) => <div key={field.id} className="rounded-xl border border-border/70 p-4"><div className="grid gap-4 sm:grid-cols-2"><div><label className="field-label" htmlFor={`creator-benefit-key-${index}`}>Mã quyền lợi *</label><input id={`creator-benefit-key-${index}`} className="field" {...form.register(`benefits.${index}.key`)} /></div><div><label className="field-label" htmlFor={`creator-benefit-value-${index}`}>Giá trị *</label><input id={`creator-benefit-value-${index}`} className="field" {...form.register(`benefits.${index}.value`)} /></div><div className="sm:col-span-2"><label className="field-label" htmlFor={`creator-benefit-description-${index}`}>Mô tả quyền lợi</label><input id={`creator-benefit-description-${index}`} className="field" {...form.register(`benefits.${index}.description`)} /></div></div><Button type="button" variant="outline" className="mt-3" onClick={() => benefits.remove(index)}><Trash2 className="size-4" />Xóa quyền lợi</Button></div>)}</div>{fieldError('benefits') && <p className="field-error">{fieldError('benefits')}</p>}</div></fieldset>{mutation.isError && <p role="alert" className="mt-5 rounded-lg bg-destructive/10 p-3 text-sm text-destructive">{errorMessage(mutation.error)}</p>}<div className="mt-6 flex justify-end gap-3"><Button type="button" variant="outline" onClick={onClose} disabled={mutation.isPending}>Hủy</Button><Button type="submit" disabled={mutation.isPending}>{mutation.isPending ? 'Đang lưu…' : plan ? 'Lưu thay đổi' : 'Tạo gói'}</Button></div></form></section>
}

function DeactivatePlan({ plan, onDone }: { plan: CreatorSystemPlan; onDone: () => void }) {
  const client = useQueryClient()
  const notify = useFeedback()
  const initiatingIdentity = useRef<ReturnType<typeof identityOf>>(null)
  const mutation = useMutation({
    mutationFn: () => {
      const expected = initiatingIdentity.current
      if (!expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      return backend.deactivateCreatorSystemPlan(plan.planId)
    },
    onSuccess: async data => {
      const expected = initiatingIdentity.current
      if (!expected || expected.role !== 'ADMIN' || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      await creatorSystemPlanChangeConfirmed(client, expected.id, data.planId)
      if (!sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      notify(phase4SuccessMessages.creatorSystemPlanDeactivated)
      onDone()
    },
    onError: async error => {
      const expected = initiatingIdentity.current
      if (extractApiError(error).outcomeUnknown && expected && expected.role === 'ADMIN' && sameIdentity(expected, identityOf(session.getUser()))) await creatorSystemPlanChangeConfirmed(client, expected.id, plan.planId)
    },
  })
  return <ConfirmDialog trigger={<Button variant="outline" disabled={plan.status !== 'ACTIVE' || mutation.isPending}>Ngừng bán</Button>} title="Ngừng bán gói Premium?" description="Gói sẽ chuyển sang trạng thái ngừng hoạt động. Lịch sử đăng ký hiện có được Backend giữ lại." confirmLabel="Xác nhận ngừng bán" destructive onOpenChange={open => { initiatingIdentity.current = open ? identityOf(session.getUser()) : null }} onConfirm={async () => { await mutation.mutateAsync() }} />
}

function PlanDetail({ planId, onEdit, onClose }: { planId: string; onEdit: (plan: CreatorSystemPlan) => void; onClose: () => void }) {
  const { user } = useAuth()
  const query = useQuery({ queryKey: adminKeys.creatorSystemPlanDetail(user?.id, planId), enabled: user?.role === 'ADMIN', queryFn: ({ signal }) => backend.creatorSystemPlan(planId, signal) })
  const plan = query.data
  return <section className="panel h-fit"><div className="panel-heading"><div><p className="eyebrow">Chi tiết gói Premium</p><h2 className="mt-1 text-lg font-semibold">{plan?.name || 'Đang tải…'}</h2></div><Button variant="ghost" onClick={onClose}>Đóng</Button></div>{query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : plan ? <div className="space-y-4 p-6 text-sm"><div className="grid gap-4 sm:grid-cols-2"><div><p className="text-xs text-muted-foreground">Mã gói</p><p className="mt-1 font-mono">{plan.code}</p></div><div><p className="text-xs text-muted-foreground">Trạng thái</p><p className="mt-1"><span className={`badge status-${plan.status.toLowerCase()}`}>{planStatusLabel(plan.status)}</span></p></div><div><p className="text-xs text-muted-foreground">Giá</p><p className="mt-1 font-semibold">{plan.price} {plan.currency}</p></div><div><p className="text-xs text-muted-foreground">Thời hạn</p><p className="mt-1">{plan.durationDays === null ? 'Không thời hạn' : `${plan.durationDays} ngày`}</p></div></div><div><p className="text-xs text-muted-foreground">Mô tả</p><p className="mt-1 whitespace-pre-wrap break-words">{plan.description || 'Chưa có mô tả'}</p></div><div><p className="text-xs text-muted-foreground">Quyền lợi</p><div className="mt-2 space-y-2">{plan.benefits.length ? plan.benefits.map(benefit => <div key={`${benefit.key}-${benefit.value}`} className="rounded-lg border border-border/70 p-3"><p className="font-semibold">{benefit.key}: {benefit.value}</p>{benefit.description && <p className="mt-1 text-muted-foreground">{benefit.description}</p>}</div>) : <p>Chưa có quyền lợi</p>}</div></div><div className="flex flex-wrap gap-2 pt-2"><Button variant="outline" onClick={() => onEdit(plan)}><Pencil className="size-4" />Sửa gói</Button><DeactivatePlan plan={plan} onDone={onClose} /></div></div> : <EmptyState title="Không tìm thấy gói" message="Gói có thể đã thay đổi hoặc không còn tồn tại." />}</section>
}

export function CreatorSystemPlansPage() {
  const { user } = useAuth()
  const [selected, setSelected] = useState<string | null>(null)
  const [editor, setEditor] = useState<CreatorSystemPlan | 'new' | null>(null)
  const query = useQuery({ queryKey: adminKeys.creatorSystemPlans(user?.id), enabled: user?.role === 'ADMIN', queryFn: ({ signal }) => backend.creatorSystemPlans(signal) })
  return <><div className="mb-7 flex flex-wrap items-end justify-between gap-4"><div><p className="eyebrow">Quản lý hệ thống</p><h1 className="mt-2 text-3xl font-bold">Gói Premium</h1></div><div className="flex gap-3"><Button variant="outline" disabled={query.isFetching} onClick={() => { void query.refetch() }}><RefreshCw className={`size-4 ${query.isFetching ? 'motion-safe:animate-spin' : ''}`} />Làm mới</Button><Button disabled={editor !== null} onClick={() => setEditor('new')}><Plus className="size-4" />Tạo gói</Button></div></div>{editor !== null && <PlanForm key={editor === 'new' ? 'new' : editor.planId} plan={editor === 'new' ? undefined : editor} onClose={() => setEditor(null)} />}<section className="panel"><div className="panel-heading"><div><h2 className="font-semibold">Danh sách gói Premium</h2><p className="mt-1 text-xs text-muted-foreground">{query.data ? `${query.data.length} gói` : 'Đang tải từ Backend'}</p></div></div>{query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : query.data?.length ? <div className="overflow-x-auto"><table className="data-table"><thead><tr><th>Mã gói</th><th>Tên gói</th><th>Giá</th><th>Thời hạn</th><th>Trạng thái</th><th><span className="sr-only">Thao tác</span></th></tr></thead><tbody>{query.data.map(plan => <Fragment key={plan.planId}><tr className={selected === plan.planId ? 'bg-muted/40' : ''}><td className="font-mono text-xs">{plan.code}</td><td><p className="font-semibold">{plan.name}</p><p className="mt-1 text-xs text-muted-foreground">{plan.benefits.length} quyền lợi</p></td><td className="whitespace-nowrap">{plan.price} {plan.currency}</td><td>{plan.durationDays === null ? 'Không thời hạn' : `${plan.durationDays} ngày`}</td><td><span className={`badge status-${plan.status.toLowerCase()}`}>{planStatusLabel(plan.status)}</span></td><td><div className="flex justify-end gap-2"><Button variant="outline" onClick={() => setSelected(plan.planId)}><Eye className="size-4" />Chi tiết</Button><Button variant="outline" disabled={editor !== null} onClick={() => setEditor(plan)}><Pencil className="size-4" />Sửa</Button></div></td></tr>{selected === plan.planId && <tr><td colSpan={6} className="p-0"><PlanDetail planId={selected} onEdit={plan => setEditor(plan)} onClose={() => setSelected(null)} /></td></tr>}</Fragment>)}</tbody></table></div> : <EmptyState title="Chưa có gói Premium" message="Backend chưa trả về gói Premium nào." />}</section></>
}
