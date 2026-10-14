import { createContext, useCallback, useContext, useState } from 'react'
import type { ReactNode } from 'react'
import { X } from 'lucide-react'
import { Button } from './ui/button'

type Notice = { id: number; message: string; kind: 'success' | 'error' }
const FeedbackContext = createContext<(message: string, kind?: Notice['kind']) => void>(() => undefined)
export function FeedbackProvider({ children }: { children: ReactNode }) {
  const [notices, setNotices] = useState<Notice[]>([])
  const notify = useCallback((message: string, kind: Notice['kind'] = 'success') => {
    const id = Date.now() + Math.random()
    setNotices(current => [...current.slice(-3), { id, message, kind }])
    window.setTimeout(() => setNotices(current => current.filter(n => n.id !== id)), 8000)
  }, [])
  return <FeedbackContext.Provider value={notify}>{children}
    <div className="fixed right-4 bottom-4 z-[60] flex w-[calc(100%_-_2rem)] max-w-sm flex-col gap-2" aria-label="Thông báo thao tác">
      {notices.map(n => <div key={n.id} role={n.kind === 'error' ? 'alert' : 'status'} className="flex items-center gap-3 rounded-xl border border-border bg-surface p-4 shadow-lg">
        <span className={n.kind === 'error' ? 'text-destructive' : 'text-foreground'}>{n.message}</span>
        <Button variant="ghost" className="ml-auto px-2" aria-label="Đóng thông báo" onClick={() => setNotices(current => current.filter(item => item.id !== n.id))}><X className="size-4" /></Button>
      </div>)}
    </div>
  </FeedbackContext.Provider>
}
// eslint-disable-next-line react-refresh/only-export-components
export const useFeedback = () => useContext(FeedbackContext)
