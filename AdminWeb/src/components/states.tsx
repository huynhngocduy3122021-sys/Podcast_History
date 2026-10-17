import { AlertCircle, Inbox, LoaderCircle } from 'lucide-react'
import { Button } from './ui/button'

export function LoadingState({ message = 'Đang tải dữ liệu…' }: { message?: string }) {
  return <div role="status" className="state-panel"><LoaderCircle className="size-6 motion-safe:animate-spin" aria-hidden="true" /><p>{message}</p></div>
}
export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return <div role="alert" className="state-panel"><AlertCircle className="size-7 text-destructive" aria-hidden="true" /><h2 className="font-semibold">Không thể tải dữ liệu</h2><p>{message}</p>{onRetry && <Button variant="outline" onClick={onRetry}>Thử lại</Button>}</div>
}
export function EmptyState({ title, message }: { title: string; message: string }) {
  return <div className="state-panel"><Inbox className="size-8 text-muted-foreground" aria-hidden="true" /><h2 className="font-semibold">{title}</h2><p>{message}</p></div>
}
