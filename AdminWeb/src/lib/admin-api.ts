import type { AxiosInstance } from 'axios'
import { categoriesSchema, categoryFormSchema, categorySchema, creatorApplicationSchema, creatorApplicationsPageSchema, approveCreatorSchema, rejectCreatorSchema } from './admin-contracts.ts'
import type { CategoryForm, CreatorStatus } from './admin-contracts.ts'
import { confirmedMutation } from './api-mutation.ts'

// Inject the existing authenticated transport; tests use an Axios adapter, not a second runtime client.
export function createAdminApi(client: Pick<AxiosInstance, 'get' | 'post' | 'put' | 'delete'>) {
  const applications = '/api/admin/creator-applications'
  const categories = '/api/admin/categories'
  return {
    async applications(status: CreatorStatus | '', page: number, size: number, signal?: AbortSignal) {
      return creatorApplicationsPageSchema.parse((await client.get(applications, { params: { status: status || undefined, page, size }, signal })).data)
    },
    async application(applicationId: string, signal?: AbortSignal) {
      return creatorApplicationSchema.parse((await client.get(`${applications}/${encodeURIComponent(applicationId)}`, { signal })).data)
    },
    async review(applicationId: string, decision: 'approve' | 'reject', values: { note: string }) {
      const body = (decision === 'reject' ? rejectCreatorSchema : approveCreatorSchema).parse(values)
      return confirmedMutation(() => client.post(`${applications}/${encodeURIComponent(applicationId)}/${decision}`, body), creatorApplicationSchema, 200,
        data => data.applicationId === applicationId && data.status === (decision === 'approve' ? 'APPROVED' : 'REJECTED'))
    },
    async categories(signal?: AbortSignal) {
      return categoriesSchema.parse((await client.get(categories, { signal })).data)
    },
    async saveCategory(categoryId: string | undefined, values: CategoryForm) {
      const body = categoryFormSchema.parse(values)
      return confirmedMutation(() => categoryId
        ? client.put(`${categories}/${encodeURIComponent(categoryId)}`, body)
        : client.post(categories, body), categorySchema, categoryId ? 200 : 201,
        data => (!categoryId || data.categoryId === categoryId) && data.active === body.active && data.name === body.name)
    },
    async deactivateCategory(categoryId: string) {
      return confirmedMutation(() => client.delete(`${categories}/${encodeURIComponent(categoryId)}`), categorySchema, 200,
        data => data.categoryId === categoryId && !data.active)
    },
  }
}
