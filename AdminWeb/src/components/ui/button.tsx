// Local shadcn/ui-style primitive; owned by this project.
import { Slot } from '@radix-ui/react-slot'
import { cva } from 'class-variance-authority'
import type { VariantProps } from 'class-variance-authority'
import type { ComponentProps } from 'react'
import { cn } from '../../lib/utils'

const variants = cva('inline-flex min-h-10 items-center justify-center gap-2 rounded-lg px-4 py-2 text-sm font-semibold transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:pointer-events-none disabled:opacity-50', {
  variants: { variant: {
    default: 'bg-primary text-on-primary hover:bg-primary/90',
    outline: 'border border-border bg-surface text-foreground hover:bg-muted',
    ghost: 'text-muted-foreground hover:bg-muted hover:text-foreground',
    destructive: 'bg-destructive text-on-destructive hover:bg-destructive/90',
  } }, defaultVariants: { variant: 'default' },
})
export function Button({ className, variant, asChild = false, type = 'button', ...props }: ComponentProps<'button'> & VariantProps<typeof variants> & { asChild?: boolean }) {
  const Component = asChild ? Slot : 'button'
  return <Component type={asChild ? undefined : type} className={cn(variants({ variant }), className)} {...props} />
}
