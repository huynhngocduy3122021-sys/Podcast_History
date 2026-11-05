import { useEffect, useMemo, useRef, useState } from 'react'
import type { IAgoraRTCClient } from 'agora-rtc-sdk-ng'
import { api, errorMessage } from '../lib/client'
import { createModerationApi } from '../lib/moderation-api'
import type { Role } from '../lib/permissions'

export function ReportedLivestreamPlayer({ reportId, role, onReadyChange }: {
  reportId: string
  role: Role
  onReadyChange: (ready: boolean) => void
}) {
  const backend = useMemo(() => createModerationApi(api, role), [role])
  const readyCallback = useRef(onReadyChange)
  readyCallback.current = onReadyChange
  const video = useRef<HTMLDivElement>(null)
  const clientRef = useRef<IAgoraRTCClient | null>(null)
  const [message, setMessage] = useState('Đang kết nối livestream…')

  useEffect(() => {
    let disposed = false
    let rtc: IAgoraRTCClient | null = null
    const connect = async () => {
      try {
        const { default: AgoraRTC } = await import('agora-rtc-sdk-ng')
        if (disposed) return
        rtc = AgoraRTC.createClient({ mode: 'live', codec: 'vp8', role: 'audience' })
        const client = rtc
        clientRef.current = client
        client.on('user-published', async (remoteUser, mediaType) => {
          try {
            await client.subscribe(remoteUser, mediaType)
            if (disposed) return
            if (mediaType === 'video' && video.current) {
              remoteUser.videoTrack?.play(video.current)
              setMessage('Đang xem livestream trực tiếp')
            }
            if (mediaType === 'audio') remoteUser.audioTrack?.play()
          } catch (error) {
            if (!disposed) setMessage(`Không thể nhận tín hiệu: ${errorMessage(error)}`)
          }
        })
        client.on('user-unpublished', (_remoteUser, mediaType) => {
          if (!disposed && mediaType === 'video') setMessage('Đang chờ tín hiệu video từ Creator…')
        })
        client.on('token-privilege-will-expire', async () => {
          try {
            const renewed = await backend.joinReportedLivestream(reportId)
            if (!disposed) await client.renewToken(renewed.token)
          } catch (error) {
            if (!disposed) setMessage(`Không thể gia hạn phiên xem: ${errorMessage(error)}`)
          }
        })
        const join = await backend.joinReportedLivestream(reportId)
        if (disposed) return
        await client.join(join.appId, join.channelName, join.token, join.userAccount)
        if (disposed) {
          await client.leave()
          return
        }
        readyCallback.current(true)
        setMessage('Đã kết nối, đang chờ tín hiệu từ Creator…')
      } catch (error) {
        if (!disposed) setMessage(`Không thể xem livestream: ${errorMessage(error)}`)
      }
    }
    void connect()
    return () => {
      disposed = true
      readyCallback.current(false)
      clientRef.current = null
      if (rtc) void rtc.leave()
    }
  }, [backend, reportId])

  return <div className="space-y-2 rounded-lg border border-border p-3">
    <div ref={video} className="aspect-video w-full overflow-hidden rounded-md bg-black" aria-label="Video livestream được báo cáo" />
    <div className="flex flex-wrap items-center justify-between gap-2 text-sm">
      <span>{message}</span>
      <button type="button" className="rounded-md border border-border px-3 py-2 font-medium" onClick={() => {
        for (const user of clientRef.current?.remoteUsers ?? []) user.audioTrack?.play()
      }}>Bật âm thanh</button>
    </div>
  </div>
}
