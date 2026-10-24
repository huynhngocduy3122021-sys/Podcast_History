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
  return <main className="grid min-h-screen lg:grid-cols-2">
    <section className="login-brand hidden flex-col justify-between p-14 lg:flex">
      <div className="flex items-center gap-3 text-xl font-bold"><Headphones className="size-8" /> VietCast<span className="text-sm font-normal opacity-60">/ Quản trị</span></div>
      <div><p className="mb-5 text-xs font-semibold tracking-[.2em] uppercase opacity-65">Lịch sử được kể. Nội dung được gìn giữ.</p><h1 className="max-w-lg text-5xl font-semibold leading-tight">Một không gian<br />cho những người<br />giữ chất lượng.</h1><p className="mt-6 max-w-sm leading-7 opacity-70">Quản lý nội dung và vận hành VietCast với thông tin rõ ràng, quyền truy cập phù hợp.</p></div>
      <p className="text-xs opacity-55">VIETCAST · ADMIN & STAFF WORKSPACE</p>
    </section>
    <section className="flex items-center justify-center p-6 sm:p-12">
      <div className="w-full max-w-sm"><div className="mb-10 flex size-12 items-center justify-center rounded-2xl bg-primary/10 text-primary"><ShieldCheck /></div><p className="eyebrow">Chào mừng trở lại</p><h2 className="mt-3 text-3xl font-bold">Đăng nhập quản trị</h2><p className="mt-3 text-sm text-muted-foreground">Dành cho tài khoản ADMIN và STAFF.</p>
        <form className="mt-8 space-y-5" onSubmit={submit} noValidate>
          <div><label htmlFor="identifier" className="field-label">Tên đăng nhập hoặc email</label><input id="identifier" className="field" autoComplete="username" aria-invalid={!!errors.identifier} aria-describedby={errors.identifier ? 'identifier-error' : undefined} {...register('identifier')} />{errors.identifier && <p id="identifier-error" className="field-error">{errors.identifier.message}</p>}</div>
          <div><label htmlFor="password" className="field-label">Mật khẩu</label><input id="password" type="password" className="field" autoComplete="current-password" aria-invalid={!!errors.password} aria-describedby={errors.password ? 'password-error' : undefined} {...register('password')} />{errors.password && <p id="password-error" className="field-error">{errors.password.message}</p>}</div>
          {(failure || initializationError) && <p role="alert" className="rounded-lg bg-destructive/5 p-3 text-sm text-destructive">{failure || initializationError}</p>}
          <Button type="submit" className="w-full" disabled={isSubmitting}>{isSubmitting ? 'Đang đăng nhập…' : 'Đăng nhập'}</Button>
        </form><p className="mt-8 text-xs leading-5 text-muted-foreground">Chưa có quyền truy cập? Liên hệ quản trị viên để được cấp tài khoản. Trang này không hỗ trợ tự đăng ký.</p>
      </div>
    </section>
  </main>
}
