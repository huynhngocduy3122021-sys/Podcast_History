import { Navigate, Route, Routes } from 'react-router-dom'
import { ForbiddenPage, ProtectedRoute, RoleRoute } from './auth'
import { Layout } from './components/layout'
import { LoginPage } from './pages/login'
import { DashboardPage } from './pages/dashboard'
import { CreatorApprovalPage } from './pages/creator-approval'
import { CategoriesPage } from './pages/categories'
import { NotFoundPage, PlaceholderPage } from './pages/placeholder'
import { PodcastModerationPage, ReportsPage, AppealsPage } from './pages/moderation-pages'
import { UsersPage } from './pages/users'
import { StaffPage } from './pages/staff'
import { MembershipPlansPage } from './pages/membership-plans'
import { AuditLogsPage } from './pages/audit-logs'
import { NotificationsPage } from './pages/notifications'
import { PaymentsPage } from './pages/payments'
import { WalletsPage } from './pages/wallets'
import { WithdrawalsPage } from './pages/withdrawals'
import { ContractsPage } from './pages/contracts'
import { DisputesPage } from './pages/disputes'
import { sections } from './lib/permissions'

export function App() {
  return <Routes><Route path="/login" element={<LoginPage />} /><Route path="/forbidden" element={<ForbiddenPage />} />
    <Route element={<ProtectedRoute />}><Route element={<Layout />}><Route index element={<Navigate to="/dashboard" replace />} />
      {sections.map(s => <Route key={s.path} element={<RoleRoute adminOnly={'adminOnly' in s && s.adminOnly} />}><Route path={s.path} element={s.path === '/dashboard' ? <DashboardPage /> : s.path === '/creator-approval' ? <CreatorApprovalPage /> : s.path === '/categories' ? <CategoriesPage /> : s.path === '/podcast-moderation' ? <PodcastModerationPage /> : s.path === '/reports' ? <ReportsPage /> : s.path === '/appeals' ? <AppealsPage /> : s.path === '/users' ? <UsersPage /> : s.path === '/staff' ? <StaffPage /> : s.path === '/membership-plans' ? <MembershipPlansPage /> : s.path === '/payments' ? <PaymentsPage /> : s.path === '/wallets' ? <WalletsPage /> : s.path === '/withdrawals' ? <WithdrawalsPage /> : s.path === '/contracts' ? <ContractsPage /> : s.path === '/disputes' ? <DisputesPage /> : s.path === '/notifications' ? <NotificationsPage /> : s.path === '/audit-logs' ? <AuditLogsPage /> : <PlaceholderPage title={s.label} />} /></Route>)}
      <Route path="*" element={<NotFoundPage />} />
    </Route></Route>
  </Routes>
}
