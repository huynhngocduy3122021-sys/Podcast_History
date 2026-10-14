import { useEffect, useState } from 'react'
import { NavLink, Outlet, useLocation } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { Activity, Bell, ChevronLeft, ChevronRight, CircleHelp, CreditCard, FileCheck, Folder, Gavel, Headphones, LayoutDashboard, LogOut, Menu, Mic, ScrollText, ShieldCheck, UserCheck, Users, Wallet } from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import { useAuth } from '../auth'
import { sections, canAccess } from '../lib/permissions'
import { session, errorMessage } from '../lib/client'
import { Button } from './ui/button'
import { ConfirmDialog } from './ui/confirm-dialog'
import { useFeedback } from './feedback'
import { NotificationDropdown } from './notification-dropdown'
import { ThemeToggle } from './theme-toggle'

const icons: Record<string, LucideIcon> = { dashboard: LayoutDashboard, creator: UserCheck, podcast: Mic, report: ShieldCheck, appeal: CircleHelp, users: Users, staff: UserCheck, category: Folder, plan: FileCheck, payment: CreditCard, withdrawal: Wallet, wallet: Wallet, contract: ScrollText, dispute: Gavel, notification: Bell, audit: Activity }
export function Layout() {
  const { user } = useAuth()
  const [expanded, setExpanded] = useState(false)
  const [collapsed, setCollapsed] = useState(() => {
    try { return localStorage.getItem('vietcast.admin.sidebar-collapsed') === 'true' } catch { return false }
  })
  useEffect(() => {
    try { localStorage.setItem('vietcast.admin.sidebar-collapsed', String(collapsed)) } catch { /* Keep the current layout in memory. */ }
  }, [collapsed])
  useEffect(() => {
    if (!expanded) return
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setExpanded(false)
        document.getElementById('open-navigation')?.focus()
      }
    }
    window.addEventListener('keydown', closeOnEscape)
    return () => window.removeEventListener('keydown', closeOnEscape)
  }, [expanded])
  const location = useLocation()
  const queryClient = useQueryClient()
  const notify = useFeedback()
  const current = sections.find(s => s.path === location.pathname)
  const visible = sections.filter(s => canAccess(user?.role, 'adminOnly' in s && s.adminOnly))
  const groups = [...new Set(visible.map(s => s.group))]
  const logout = async () => {
    queryClient.clear()
    try { await session.logout(); notify('Đã đăng xuất.') }
    catch (error) { notify(`Đã xóa phiên trên máy. Chưa xác nhận thu hồi phiên trên máy chủ: ${errorMessage(error)}`, 'error') }
  }
  return <div className="min-h-screen">
    <a href="#main-content" className="sr-only focus:not-sr-only focus:fixed focus:z-[70] focus:bg-surface focus:p-4">Đi đến nội dung</a>
    {expanded && <button className="fixed inset-0 z-30 bg-black/40 lg:hidden" aria-label="Đóng menu điều hướng" onClick={() => setExpanded(false)} />}
    <aside id="workspace-navigation" className={`sidebar ${expanded ? 'visible translate-x-0' : 'invisible -translate-x-full'} ${collapsed ? 'lg:w-20' : 'lg:w-64'} lg:visible lg:translate-x-0`}>
      <div className={`flex items-center gap-3 px-6 py-7 ${collapsed ? 'lg:px-4' : ''}`}><span className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-primary text-on-primary" title="VietCast"><Headphones className="size-6" /></span><div className={collapsed ? 'lg:hidden' : ''}><div className="text-xl font-bold tracking-tight">VietCast</div><div className="text-[10px] font-semibold tracking-[.18em] text-muted-foreground uppercase">Admin workspace</div></div><Button variant="ghost" className="ml-auto px-2 lg:hidden" aria-label="Đóng menu" onClick={() => setExpanded(false)}><ChevronLeft /></Button></div>
      <Button variant="outline" className="absolute -right-4 top-8 hidden size-8 min-h-0 rounded-full p-0 shadow-sm lg:inline-flex" aria-label={collapsed ? 'Mở rộng sidebar' : 'Thu gọn sidebar'} title={collapsed ? 'Mở rộng sidebar' : 'Thu gọn sidebar'} aria-expanded={!collapsed} aria-controls="sidebar-links" onClick={() => setCollapsed(current => !current)}>{collapsed ? <ChevronRight className="size-4" /> : <ChevronLeft className="size-4" />}</Button>
      <nav id="sidebar-links" className="flex-1 overflow-y-auto px-3 pb-4" aria-label="Điều hướng chính">{groups.map(group => <div key={group} className="mt-5"><p className={`px-3 pb-2 text-[10px] font-semibold tracking-wider text-muted-foreground uppercase ${collapsed ? 'lg:sr-only' : ''}`}>{group}</p>{visible.filter(s => s.group === group).map(s => {
        const Icon = icons[s.icon]
        return <NavLink key={s.path} to={s.path} title={s.label} onClick={() => setExpanded(false)} className={({ isActive }) => `nav-item ${isActive ? 'nav-item-active' : ''} ${collapsed ? 'lg:justify-center lg:px-2' : ''}`}><Icon className="size-[18px] shrink-0" aria-hidden="true" /><span className={collapsed ? 'lg:sr-only' : ''}>{s.label}</span></NavLink>
      })}</div>)}</nav>
      <div className={`border-t border-border p-4 ${collapsed ? 'lg:px-3' : ''}`}><ThemeToggle collapsed={collapsed} /></div>
    </aside>
    <div className={`transition-[padding] motion-reduce:transition-none ${collapsed ? 'lg:pl-20' : 'lg:pl-64'}`}><header className="topbar"><div className="flex min-w-0 items-center gap-3"><Button id="open-navigation" variant="ghost" className="px-2 lg:hidden" aria-label="Mở menu" aria-expanded={expanded} aria-controls="workspace-navigation" onClick={() => setExpanded(true)}><Menu /></Button><nav aria-label="Breadcrumb" className="flex items-center gap-2 text-sm"><NavLink to="/dashboard" className="hidden text-muted-foreground sm:block">Quản trị</NavLink><ChevronRight className="hidden size-4 text-muted-foreground sm:block" /><span className="font-medium">{current?.label || 'Trang không tồn tại'}</span></nav></div>
      <div className="flex shrink-0 items-center gap-2 sm:gap-4"><NotificationDropdown /><div className="hidden text-right sm:block"><p className="text-sm font-semibold">{user?.displayName || user?.username}</p><p className="text-[11px] text-muted-foreground">{user?.role}</p></div><span className="flex size-9 items-center justify-center rounded-full bg-muted text-sm font-bold" aria-hidden="true">{(user?.displayName || user?.username || 'V').slice(0, 1).toUpperCase()}</span><ConfirmDialog trigger={<Button variant="ghost" className="px-2" aria-label="Đăng xuất"><LogOut className="size-5" /></Button>} title="Đăng xuất khỏi VietCast?" description="Phiên đăng nhập trên máy này sẽ được xóa và refresh token sẽ được gửi tới Backend để thu hồi." confirmLabel="Đăng xuất" onConfirm={logout} /></div>
    </header>
    <main id="main-content" className="mx-auto max-w-[1440px] p-5 sm:p-8 xl:p-10" tabIndex={-1}><Outlet /></main>
    <footer className="px-8 py-5 text-xs text-muted-foreground">VietCast · Không gian quản trị · Phase 2</footer></div>
  </div>
}
