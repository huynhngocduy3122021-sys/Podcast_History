import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useRef } from 'react'
import { api, session } from './client'
import { extractApiError } from './api-error'
import { identityOf, sameIdentity } from './identity'
import type { NotificationsPage } from './contracts'
import { createNotificationApi, markNotificationReadInCache, notificationKeys } from './notifications'

const backend = createNotificationApi(api)
const sessionChangedMessage = 'Phiên đăng nhập đã thay đổi. Vui lòng tải lại thông báo trước khi tiếp tục.'

export function useNotificationRead() {
  const client = useQueryClient()
  const initiatingIdentity = useRef<ReturnType<typeof identityOf>>(null)
  const mutation = useMutation({
    mutationFn: (notificationId: string) => {
      const expected = initiatingIdentity.current
      if (!expected || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      return backend.markRead(notificationId)
    },
    onSuccess: async (_data, notificationId) => {
      const expected = initiatingIdentity.current
      if (!expected || !sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
      client.setQueriesData<NotificationsPage>({ queryKey: notificationKeys.user(expected.id) }, page => markNotificationReadInCache(page, notificationId))
      await client.invalidateQueries({ queryKey: notificationKeys.user(expected.id) })
      if (!sameIdentity(expected, identityOf(session.getUser()))) throw new Error(sessionChangedMessage)
    },
    onError: async error => {
      const expected = initiatingIdentity.current
      if (!extractApiError(error).outcomeUnknown || !expected || !sameIdentity(expected, identityOf(session.getUser()))) return
      try { await client.invalidateQueries({ queryKey: notificationKeys.user(expected.id) }) } catch { /* Keep the uncertain outcome visible to the operator. */ }
    },
  })
  return {
    markRead: (notificationId: string) => {
      initiatingIdentity.current = identityOf(session.getUser())
      return mutation.mutateAsync(notificationId)
    },
    isPending: mutation.isPending,
    error: mutation.error,
  }
}
