import { createContext, useContext, useEffect, useState, useSyncExternalStore } from 'react'
import type { ReactNode } from 'react'
import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { canAccess } from './lib/permissions'
import { session, errorMessage } from './lib/client'
import type { User } from './lib/contracts'
import { LoadingState } from './components/states'
import { Button } from './components/ui/button'

const AuthContext = createContext<{ user: User | null; initializing: boolean; initializationError: string | null }>({ user: null, initializing: true, initializationError: null })
// One initialization promise even if React StrictMode remounts effects.
let initialization: Promise<void> | undefined
export function AuthProvider({ children }: { children: ReactNode }) {
  const user = useSyncExternalStore(session.subscribe, session.getUser, () => null)
  const sessionError = useSyncExternalStore(session.subscribe, session.getError, () => null)
  const [initializing, setInitializing] = useState(true)
  const [initializationError, setInitializationError] = useState<string | null>(null)
  useEffect(() => {
    let active = true
    initialization ??= session.initialize()
    initialization.catch(error => { if (active) setInitializationError(errorMessage(error)) })
      .finally(() => { if (active) setInitializing(false) })
    return () => { active = false }
  }, [])
  useEffect(() => {
    if (user) setInitializationError(null)
  }, [user])
  return <AuthContext.Provider value={{ user, initializing, initializationError: sessionError || initializationError }}>{children}</AuthContext.Provider>
}
// eslint-disable-next-line react-refresh/only-export-components
export const useAuth = () => useContext(AuthContext)
export function ProtectedRoute() {
  const { user, initializing } = useAuth()
  const location = useLocation()
  if (initializing) return <LoadingState message="Đang xác minh phiên đăng nhập…" />
  if (!user) return <Navigate to="/login" replace state={{ from: location.pathname }} />
  if (!canAccess(user.role)) return <Navigate to="/forbidden" replace />
  return <Outlet />
}
export function RoleRoute({ adminOnly = false }: { adminOnly?: boolean }) {
  const { user } = useAuth()
  return canAccess(user?.role, adminOnly) ? <Outlet /> : <Navigate to="/forbidden" replace />
}
export function ForbiddenPage() {
  return <main className="state-panel min-h-screen"><p className="eyebrow">403 · Quyền truy cập</p><h1 className="text-2xl font-bold">Bạn không có quyền vào trang này</h1><p>Quyền của tài khoản được Backend xác định.</p><Button asChild><a href="/dashboard">Về tổng quan</a></Button></main>
}
