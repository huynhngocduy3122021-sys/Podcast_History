export type Role = 'ADMIN' | 'STAFF'
export function isRole(value: unknown): value is Role {
  return value === 'ADMIN' || value === 'STAFF'
}
export function canAccess(role: unknown, adminOnly = false): boolean {
  return isRole(role) && (!adminOnly || role === 'ADMIN')
}
export function apiPrefix(_role: Role) {
  void _role
  return '/api/admin'
}

export const sections = [
  { path: '/dashboard', label: 'Tổng quan', group: 'Không gian làm việc', icon: 'dashboard' },
  { path: '/creator-approval', label: 'Duyệt Creator', group: 'Nội dung', icon: 'creator', adminOnly: true },
  { path: '/podcast-moderation', label: 'Kiểm duyệt podcast', group: 'Nội dung', icon: 'podcast' },
  { path: '/reports', label: 'Báo cáo vi phạm', group: 'Nội dung', icon: 'report' },
  { path: '/appeals', label: 'Khiếu nại podcast', group: 'Nội dung', icon: 'appeal' },
  { path: '/users', label: 'Người dùng', group: 'Quản lý', icon: 'users', adminOnly: true },
  { path: '/staff', label: 'Nhân viên', group: 'Quản lý', icon: 'staff', adminOnly: true },
  { path: '/categories', label: 'Danh mục', group: 'Quản lý', icon: 'category', adminOnly: true },
  { path: '/membership-plans', label: 'Gói thành viên', group: 'Quản lý', icon: 'plan', adminOnly: true },
  { path: '/creator-system-plans', label: 'Gói Premium', group: 'Quản lý', icon: 'plan', adminOnly: true },
  { path: '/payments', label: 'Thanh toán', group: 'Tài chính & hợp đồng', icon: 'payment', adminOnly: true },
  { path: '/withdrawals', label: 'Rút tiền', group: 'Tài chính & hợp đồng', icon: 'withdrawal', adminOnly: true },
  { path: '/wallets', label: 'Ví', group: 'Tài chính & hợp đồng', icon: 'wallet', adminOnly: true },
  { path: '/contracts', label: 'Hợp đồng', group: 'Tài chính & hợp đồng', icon: 'contract', adminOnly: true },
  { path: '/disputes', label: 'Tranh chấp', group: 'Tài chính & hợp đồng', icon: 'dispute', adminOnly: true },
  { path: '/notifications', label: 'Thông báo', group: 'Hệ thống', icon: 'notification' },
  { path: '/audit-logs', label: 'Nhật ký quản trị', group: 'Hệ thống', icon: 'audit', adminOnly: true },
] satisfies { path: string; label: string; group: string; icon: string; adminOnly?: boolean }[]
