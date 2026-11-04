import { useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { session } from './client.ts'
import { notificationKeys } from './notifications.ts'
import { parseStompFrame, stompFrame } from './realtime-protocol.ts'

function websocketUrl() {
  const configured = import.meta.env.VITE_WS_URL?.trim()
  if (configured) return configured.replace(/\/$/, '')
  const base = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:8081').replace(/\/$/, '')
  return `${base.replace(/^http/, 'ws')}/ws`
}

function invalidateRealtimeEvent(queryClient: ReturnType<typeof useQueryClient>, userId: string, body: string) {
  queryClient.invalidateQueries({ queryKey: notificationKeys.user(userId) })
  try {
    const event = JSON.parse(body) as { type?: string }
    if (event.type === 'API_CHANGED' || event.type === 'NOTIFICATION_CHANGED' || event.type === 'CONTRACT_CHAT_MESSAGE') {
      queryClient.invalidateQueries({ predicate: query => query.queryKey.some(value => value === userId) })
    }
  } catch { /* A malformed realtime payload cannot replace REST state. */ }
}

export function useAdminRealtime(userId: string | undefined) {
  const queryClient = useQueryClient()
  useEffect(() => {
    if (!userId) return
    let socket: WebSocket | null = null
    let reconnectTimer: ReturnType<typeof setTimeout> | undefined
    let stopped = false
    let attempt = 0
    const connect = () => {
      if (stopped) return
      const token = session.getAccessToken()
      if (!token) return
      try { socket = new WebSocket(websocketUrl()) } catch { schedule(); return }
      socket.onopen = () => {
        attempt = 0
        socket?.send(stompFrame('CONNECT', { 'accept-version': '1.2', Authorization: `Bearer ${token}`, host: new URL(websocketUrl()).host }))
      }
      socket.onmessage = event => {
        if (typeof event.data !== 'string') return
        const parsed = parseStompFrame(event.data)
        if (!parsed) return
        if (parsed.command === 'CONNECTED') {
          socket?.send(stompFrame('SUBSCRIBE', { id: 'notifications', destination: '/user/queue/notifications', ack: 'auto' }))
          socket?.send(stompFrame('SUBSCRIBE', { id: 'api-changes', destination: '/user/queue/api-changes', ack: 'auto' }))
          socket?.send(stompFrame('SUBSCRIBE', { id: 'realtime', destination: '/user/queue/realtime', ack: 'auto' }))
          socket?.send(stompFrame('SUBSCRIBE', { id: 'contract-chat', destination: '/user/queue/contract-chat', ack: 'auto' }))
        } else if (parsed.command === 'MESSAGE') invalidateRealtimeEvent(queryClient, userId, parsed.body)
      }
      socket.onerror = () => socket?.close()
      socket.onclose = () => { socket = null; schedule() }
    }
    const schedule = () => {
      if (stopped || reconnectTimer) return
      const delay = Math.min(30000, 1000 * (2 ** Math.min(attempt++, 5)))
      reconnectTimer = setTimeout(() => { reconnectTimer = undefined; connect() }, delay)
    }
    const unsubscribeSession = session.subscribe(() => { socket?.close() })
    connect()
    return () => {
      stopped = true
      unsubscribeSession()
      if (reconnectTimer) clearTimeout(reconnectTimer)
      if (socket?.readyState === WebSocket.OPEN) socket.send(stompFrame('DISCONNECT', { receipt: 'shutdown' }))
      socket?.close()
    }
  }, [queryClient, userId])
}
