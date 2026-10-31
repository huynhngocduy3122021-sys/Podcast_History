import type { AxiosInstance } from 'axios'
import { confirmedNoContent } from './api-mutation.ts'
import { notificationsPageSchema } from './contracts.ts'
import type { NotificationsPage } from './contracts.ts'

export const notificationKeys = {
  user: (userId: string) => ['notifications', userId] as const,
  page: (userId: string, page: number, size: number) => ['notifications', userId, 'page', page, size] as const,
}

export function createNotificationApi(client: Pick<AxiosInstance, 'get' | 'put'>) {
  return {
    async list(page: number, size: number, signal?: AbortSignal) {
      return notificationsPageSchema.parse((await client.get('/api/me/notifications', { params: { page, size }, signal })).data)
    },
    async markRead(notificationId: string) {
      return confirmedNoContent(() => client.put(`/api/me/notifications/${encodeURIComponent(notificationId)}/read`))
    },
  }
}

export function markNotificationReadInCache(page: NotificationsPage | undefined, notificationId: string) {
  if (!page) return page
  return { ...page, content: page.content.map(item => item.notificationId === notificationId ? { ...item, read: true, readAt: item.readAt || new Date().toISOString() } : item) }
}

export function countUnreadNotifications(page: NotificationsPage | undefined) {
  return page?.content.reduce((count, item) => count + (item.read ? 0 : 1), 0) || 0
}
