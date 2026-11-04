import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { Navigate, useLocation, useNavigate } from 'react-router-dom'
import { Headphones, ShieldCheck } from 'lucide-react'
import { loginSchema } from '../lib/contracts'
import { session, errorMessage } from '../lib/client'
import { sections, canAccess } from '../lib/permissions'
import { useAuth } from '../auth'
import { Button } from '../components/ui/button'
import { LoadingState } from '../components/states'

export function LoginPage() {
  const { user, initializing, initializationError } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const [failure, setFailure] = useState<string | null>(null)
  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm({ resolver: zodResolver(loginSchema), defaultValues: { identifier: '', password: '' } })
  if (initializing) return <LoadingState message="Đang xác minh phiên đăng nhập…" />
  if (user) return <Navigate to="/dashboard" replace />
  const submit = handleSubmit(async values => {
    setFailure(null)
    try {
      await session.login(values)
      const candidate = sections.find(s => s.path === location.state?.from)
      const nextUser = session.getUser()
      navigate(candidate && canAccess(nextUser?.role, 'adminOnly' in candidate && candidate.adminOnly) ? candidate.path : '/dashboard', { replace: true })
    } catch (error) { setFailure(errorMessage(error)) }
  })
  return <main className="min-h-screen bg-muted/30 lg:flex">
    <section className="login-brand relative hidden min-h-screen w-1/3 shrink-0 overflow-hidden flex-col justify-between p-10 lg:flex xl:p-14">
      <div className="relative z-10 flex items-center gap-3 text-xl font-bold"><span className="flex size-11 items-center justify-center rounded-2xl bg-primary text-on-primary"><Headphones className="size-6" /></span> VietCast<span className="text-sm font-normal opacity-60">/ Quản trị</span></div>
      <div className="login-visual-art" aria-hidden="true"><div className="login-visual-ring login-visual-ring-one" /><div className="login-visual-ring login-visual-ring-two" /><div className="login-visual-orb"><Headphones className="size-16" /></div></div>
      <div className="relative z-10 flex items-center justify-between text-xs opacity-55"><span>VIETCAST</span><span>ADMIN WORKSPACE</span></div>
    </section>
    <section className="flex flex-1 items-center justify-center p-5 sm:p-10 lg:p-14">
      <div className="w-full max-w-md rounded-3xl border border-border/80 bg-surface p-6 shadow-[0_24px_70px_rgba(38,31,26,0.08)] sm:p-10"><div className="mb-8 flex items-center gap-3 lg:hidden"><span className="flex size-10 items-center justify-center rounded-xl bg-primary text-on-primary"><Headphones className="size-5" /></span><span className="text-lg font-bold">VietCast</span></div><div className="mb-8 flex size-12 items-center justify-center rounded-2xl bg-primary/10 text-primary"><ShieldCheck /></div><p className="eyebrow">Khu vực quản trị</p><h2 className="mt-3 text-3xl font-bold tracking-tight">Đăng nhập</h2><p className="mt-3 text-sm leading-6 text-muted-foreground">Dành cho tài khoản ADMIN và STAFF.</p>
        <form className="mt-8 space-y-5" onSubmit={submit} noValidate>
          <div><label htmlFor="identifier" className="field-label">Tên đăng nhập hoặc email</label><input id="identifier" className="field" autoComplete="username" aria-invalid={!!errors.identifier} aria-describedby={errors.identifier ? 'identifier-error' : undefined} {...register('identifier')} />{errors.identifier && <p id="identifier-error" className="field-error">{errors.identifier.message}</p>}</div>
          <div><label htmlFor="password" className="field-label">Mật khẩu</label><input id="password" type="password" className="field" autoComplete="current-password" aria-invalid={!!errors.password} aria-describedby={errors.password ? 'password-error' : undefined} {...register('password')} />{errors.password && <p id="password-error" className="field-error">{errors.password.message}</p>}</div>
          {(failure || initializationError) && <p role="alert" className="rounded-lg bg-destructive/5 p-3 text-sm text-destructive">{failure || initializationError}</p>}
          <Button type="submit" className="w-full" disabled={isSubmitting}>{isSubmitting ? 'Đang đăng nhập…' : 'Đăng nhập'}</Button>
        </form><p className="mt-8 border-t border-border/70 pt-6 text-xs leading-5 text-muted-foreground">Chưa có quyền truy cập? Liên hệ quản trị viên để được cấp tài khoản.</p>
      </div>
    </section>
  </main>
}
