import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { Pencil, Plus, RefreshCw } from 'lucide-react'
import { useAuth } from '../auth'
import { api, errorMessage, session } from '../lib/client'
import { extractApiError } from '../lib/api-error'
import { createAdminApi } from '../lib/admin-api'
import { adminKeys, categoryChangeConfirmed } from '../lib/admin-cache'
import { categorySaveSuccess, successMessages } from '../lib/success-feedback'
import { categoryFormSchema } from '../lib/admin-contracts'
import type { Category, CategoryForm } from '../lib/admin-contracts'
import { Button } from '../components/ui/button'
import { ConfirmDialog } from '../components/ui/confirm-dialog'
import { EmptyState, ErrorState, LoadingState } from '../components/states'
import { useFeedback } from '../components/feedback'

const backend = createAdminApi(api)

function CategoryEditor({ category, onClose }: { category?: Category; onClose: () => void }) {
  const { user } = useAuth()
  const client = useQueryClient()
  const notify = useFeedback()
  const form = useForm({
    resolver: zodResolver(categoryFormSchema),
    defaultValues: { name: category?.name || '', slug: category?.slug || '', description: category?.description || '', active: category?.active ?? true },
  })
  const mutation = useMutation({
    mutationFn: (values: CategoryForm) => backend.saveCategory(category?.categoryId, values),
    onSuccess: async data => {
      if (session.getUser()?.id !== user?.id || session.getUser()?.role !== 'ADMIN') return
      await categoryChangeConfirmed(client, user?.id)
      if (session.getUser()?.id !== user?.id || session.getUser()?.role !== 'ADMIN') return
      notify(categorySaveSuccess(category, data))
      onClose()
    },
    onError: async error => {
      if (!extractApiError(error).outcomeUnknown || session.getUser()?.id !== user?.id || session.getUser()?.role !== 'ADMIN') return
      notify(errorMessage(error), 'error')
      await categoryChangeConfirmed(client, user?.id)
    },
  })
  const submit = form.handleSubmit(async values => {
    form.clearErrors()
    mutation.reset()
    try { await mutation.mutateAsync(values) }
    catch (error) {
      const failure = extractApiError(error)
      for (const field of ['name', 'slug', 'description', 'active'] as const) {
        if (failure.fieldErrors[field]) form.setError(field, { type: 'server', message: failure.fieldErrors[field] }, { shouldFocus: true })
      }
    }
  })
  return <section className="panel mb-6" aria-label={category ? 'Chỉnh sửa danh mục' : 'Tạo danh mục'}>
    <div className="panel-heading"><h2 className="text-lg font-semibold">{category ? `Chỉnh sửa: ${category.name}` : 'Tạo danh mục mới'}</h2></div>
    <form onSubmit={submit} noValidate className="p-6">
      <fieldset disabled={mutation.isPending || form.formState.isSubmitting} className="grid gap-5 sm:grid-cols-2">
        <div><label className="field-label" htmlFor="category-name">Tên danh mục *</label><input id="category-name" autoFocus className="field" maxLength={120} aria-invalid={!!form.formState.errors.name} aria-describedby="category-name-error" {...form.register('name')} />{form.formState.errors.name && <p id="category-name-error" className="field-error">{form.formState.errors.name.message}</p>}</div>
        <div><label className="field-label" htmlFor="category-slug">Slug *</label><input id="category-slug" className="field" maxLength={140} aria-invalid={!!form.formState.errors.slug} aria-describedby="category-slug-help category-slug-error" {...form.register('slug')} /><p id="category-slug-help" className="mt-2 text-xs text-muted-foreground">Tối đa 140 ký tự. Backend chuẩn hóa chữ thường và dấu gạch nối; tên và slug phải duy nhất.</p>{form.formState.errors.slug && <p id="category-slug-error" className="field-error">{form.formState.errors.slug.message}</p>}</div>
        <div className="sm:col-span-2"><label className="field-label" htmlFor="category-description">Mô tả</label><textarea id="category-description" className="field py-3" rows={4} maxLength={10000} aria-invalid={!!form.formState.errors.description} aria-describedby="category-description-error" {...form.register('description')} /><p className="mt-2 text-xs text-muted-foreground">Tối đa 10.000 ký tự.</p>{form.formState.errors.description && <p id="category-description-error" className="field-error">{form.formState.errors.description.message}</p>}</div>
        <div className="sm:col-span-2"><label className="flex items-center gap-3 text-sm"><input type="checkbox" className="size-4 accent-primary" {...form.register('active')} />Danh mục đang hoạt động</label><p className="mt-2 text-xs text-muted-foreground">Có thể kích hoạt lại danh mục đã ngừng hoạt động bằng cách chỉnh sửa.</p></div>
      </fieldset>
      {mutation.isError && <p role="alert" className="mt-5 rounded-lg bg-destructive/10 p-3 text-sm text-destructive">{errorMessage(mutation.error)}</p>}
      <div className="mt-6 flex flex-wrap justify-end gap-3"><Button variant="outline" disabled={mutation.isPending || form.formState.isSubmitting} onClick={onClose}>Hủy</Button><Button type="submit" disabled={user?.role !== 'ADMIN' || mutation.isPending || form.formState.isSubmitting}>{mutation.isPending ? 'Đang lưu…' : category ? 'Lưu thay đổi' : 'Tạo danh mục'}</Button></div>
    </form>
  </section>
}

function DeactivateCategory({ category, disabled }: { category: Category; disabled: boolean }) {
  const { user } = useAuth()
  const client = useQueryClient()
  const notify = useFeedback()
  const mutation = useMutation({
    mutationFn: () => backend.deactivateCategory(category.categoryId),
    onSuccess: async () => {
      if (session.getUser()?.id !== user?.id || session.getUser()?.role !== 'ADMIN') return
      await categoryChangeConfirmed(client, user?.id)
      if (session.getUser()?.id !== user?.id || session.getUser()?.role !== 'ADMIN') return
      notify(successMessages.categoryDeactivated)
    },
    onError: async error => {
      if (!extractApiError(error).outcomeUnknown || session.getUser()?.id !== user?.id || session.getUser()?.role !== 'ADMIN') return
      notify(errorMessage(error), 'error')
      await categoryChangeConfirmed(client, user?.id)
    },
  })
  return <ConfirmDialog trigger={<Button variant="outline" disabled={disabled || !category.active || user?.role !== 'ADMIN' || mutation.isPending}>Ngừng hoạt động</Button>}
    title="Ngừng hoạt động danh mục?" description={`Danh mục “${category.name}” sẽ không còn hoạt động. Các liên kết podcast và series hiện có được giữ lại.`}
    confirmLabel="Xác nhận ngừng hoạt động" destructive onConfirm={async () => { await mutation.mutateAsync() }} />
}

export function CategoriesPage() {
  const { user } = useAuth()
  const [editor, setEditor] = useState<Category | 'new' | null>(null)
  const query = useQuery({ queryKey: adminKeys.categories(user?.id), enabled: user?.role === 'ADMIN', queryFn: ({ signal }) => backend.categories(signal) })
  return <>
    <div className="mb-7 flex flex-wrap items-end justify-between gap-4"><div><p className="eyebrow">Tổ chức nội dung</p><h1 className="mt-2 text-3xl font-bold">Quản lý danh mục</h1><p className="mt-2 text-sm text-muted-foreground">Quản lý tên, slug và trạng thái của toàn bộ danh mục.</p></div><div className="flex gap-3"><Button variant="outline" disabled={query.isFetching || editor !== null} onClick={() => { void query.refetch() }}><RefreshCw className="size-4" />Làm mới</Button><Button disabled={editor !== null || user?.role !== 'ADMIN'} onClick={() => setEditor('new')}><Plus className="size-4" />Tạo danh mục</Button></div></div>
    {editor !== null && <CategoryEditor key={editor === 'new' ? 'new' : editor.categoryId} category={editor === 'new' ? undefined : editor} onClose={() => setEditor(null)} />}
    <section className="panel"><div className="panel-heading"><h2 className="font-semibold">Tất cả danh mục</h2><p className="text-xs text-muted-foreground">{query.data ? `${query.data.length} danh mục · ` : ''}Bao gồm danh mục ngừng hoạt động</p></div>
      {query.isPending ? <LoadingState /> : query.isError ? <ErrorState message={errorMessage(query.error)} onRetry={() => { void query.refetch() }} /> : query.data?.length ? <div className="overflow-x-auto"><table className="data-table"><thead><tr><th>Danh mục</th><th>Slug</th><th>Trạng thái</th><th><span className="sr-only">Thao tác</span></th></tr></thead><tbody>{query.data.map(category => <tr key={category.categoryId}><td className="max-w-xs"><p className="font-semibold">{category.name}</p><p className="mt-1 line-clamp-2 text-xs text-muted-foreground">{category.description || 'Chưa có mô tả'}</p></td><td className="max-w-xs break-all font-mono text-xs">{category.slug}</td><td><span className={`badge whitespace-nowrap ${category.active ? 'bg-success/10 text-success' : ''}`}>{category.active ? 'Đang hoạt động' : 'Ngừng hoạt động'}</span></td><td><div className="flex justify-end gap-2"><Button variant="outline" disabled={editor !== null} aria-label={`Chỉnh sửa ${category.name}`} onClick={() => setEditor(category)}><Pencil className="size-4" />Sửa</Button><DeactivateCategory category={category} disabled={editor !== null} /></div></td></tr>)}</tbody></table></div> : <EmptyState title="Chưa có danh mục" message="Tạo danh mục đầu tiên để tổ chức nội dung VietCast." />}
    </section>
  </>
}
