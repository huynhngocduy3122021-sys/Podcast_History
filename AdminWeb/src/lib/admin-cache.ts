import type { QueryClient } from '@tanstack/react-query'
import type { CreatorApplication, CreatorStatus } from './admin-contracts.ts'

export const adminKeys = {
  creators: (userId: string | undefined) => ['creator-applications', userId] as const,
  creatorList: (userId: string | undefined, status: CreatorStatus | '', page: number, size: number) => ['creator-applications', userId, 'list', status, page, size] as const,
  creatorDetail: (userId: string | undefined, applicationId: string | null) => ['creator-applications', userId, 'detail', applicationId] as const,
  categories: (userId: string | undefined) => ['categories', userId] as const,
}

export async function creatorReviewConfirmed(client: QueryClient, userId: string | undefined, application: CreatorApplication) {
  client.setQueryData(adminKeys.creatorDetail(userId, application.applicationId), application)
  await Promise.all([
    client.invalidateQueries({ queryKey: adminKeys.creators(userId) }),
    client.invalidateQueries({ queryKey: ['dashboard', userId] }),
  ])
}

export async function categoryChangeConfirmed(client: QueryClient, userId: string | undefined) {
  await client.invalidateQueries({ queryKey: adminKeys.categories(userId) })
}
