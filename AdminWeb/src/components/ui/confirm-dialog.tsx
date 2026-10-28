import * as AlertDialog from '@radix-ui/react-alert-dialog'
import { useRef, useState } from 'react'
import type { ReactNode } from 'react'
import { Button } from './button'
import { errorMessage } from '../../lib/api-error'
import { pendingAction } from '../../lib/pending-action'

export function ConfirmDialog({ trigger, title, description, confirmLabel, onConfirm, children, confirmDisabled = false, destructive = false, onOpenChange }: {
  trigger: ReactNode; title: string; description?: string; confirmLabel: string; onConfirm: () => void | Promise<void>
  children?: ReactNode; confirmDisabled?: boolean; destructive?: boolean; onOpenChange?: (open: boolean) => void
}) {
  const [open, setOpen] = useState(false)
  const [pending, setPending] = useState(false)
  const [failure, setFailure] = useState<string | null>(null)
  const run = useRef(pendingAction())
  const changeOpen = (value: boolean) => {
    if (pending) return
    setOpen(value)
    setFailure(null)
    onOpenChange?.(value)
  }
  const confirm = () => {
    if (confirmDisabled) return
    void run.current(async () => {
      setPending(true)
      setFailure(null)
      try {
        await onConfirm()
        setOpen(false)
        onOpenChange?.(false)
      } catch (error) { setFailure(errorMessage(error)) }
      finally { setPending(false) }
    })
  }
  return <AlertDialog.Root open={open} onOpenChange={changeOpen}>
    <AlertDialog.Trigger asChild>{trigger}</AlertDialog.Trigger>
    <AlertDialog.Portal>
      <AlertDialog.Overlay className="fixed inset-0 z-50 bg-black/45" />
      <AlertDialog.Content aria-busy={pending} onEscapeKeyDown={event => { if (pending) event.preventDefault() }} className="fixed top-1/2 left-1/2 z-50 max-h-[90dvh] w-[calc(100%_-_2rem)] max-w-md -translate-x-1/2 -translate-y-1/2 overflow-y-auto rounded-2xl border border-border bg-surface p-6 shadow-xl">
        <AlertDialog.Title className="text-xl font-bold">{title}</AlertDialog.Title>
        {description && <AlertDialog.Description className="mt-3 text-sm leading-6 text-muted-foreground">{description}</AlertDialog.Description>}
        {children && <fieldset disabled={pending} className="mt-5">{children}</fieldset>}
        {failure && <p role="alert" className="mt-4 rounded-lg bg-destructive/10 p-3 text-sm text-destructive">{failure}</p>}
        <div className="mt-6 flex justify-end gap-3">
          <AlertDialog.Cancel asChild><Button variant="outline" disabled={pending}>Hủy</Button></AlertDialog.Cancel>
          <AlertDialog.Action asChild><Button variant={destructive ? 'destructive' : 'default'} disabled={pending || confirmDisabled} onClick={event => { event.preventDefault(); confirm() }}>{pending ? 'Đang xử lý…' : confirmLabel}</Button></AlertDialog.Action>
        </div>
      </AlertDialog.Content>
    </AlertDialog.Portal>
  </AlertDialog.Root>
}
