import type { Category } from './admin-contracts.ts'

export const successMessages = {
  creatorApproved: 'Đã duyệt hồ sơ Creator thành công.',
  creatorRejected: 'Đã từ chối hồ sơ Creator.',
  categoryCreated: 'Tạo danh mục thành công.',
  categoryUpdated: 'Cập nhật danh mục thành công.',
  categoryDeactivated: 'Đã ngừng hoạt động danh mục.',
  categoryReactivated: 'Đã kích hoạt lại danh mục.',
  logout: 'Đã đăng xuất.',
} as const

export const phase4SuccessMessages = {
  userUpdated: 'Đã cập nhật hồ sơ người dùng.',
  userAccessChanged: 'Đã cập nhật trạng thái truy cập và thu hồi các phiên cũ.',
  userVerificationChanged: 'Đã cập nhật trạng thái xác minh.',
  userRoleChanged: 'Đã cập nhật vai trò người dùng và thu hồi các phiên cũ.',
  sessionsRevoked: 'Đã thu hồi các phiên đăng nhập của người dùng.',
  staffCreated: 'Đã tạo tài khoản Staff.',
  planCreated: 'Đã tạo gói thành viên.',
  planUpdated: 'Đã cập nhật gói thành viên.',
  planDeactivated: 'Đã chuyển gói thành không hoạt động.',
  creatorSystemPlanCreated: 'Đã tạo gói Premium.',
  creatorSystemPlanUpdated: 'Đã cập nhật gói Premium.',
  creatorSystemPlanDeactivated: 'Đã ngừng bán gói Premium.',
} as const

export function categorySaveSuccess(previous: Pick<Category, 'active'> | undefined, current: Pick<Category, 'active'>): string {
  if (!previous) return successMessages.categoryCreated
  if (!previous.active && current.active) return successMessages.categoryReactivated
  if (previous.active && !current.active) return successMessages.categoryDeactivated
  return successMessages.categoryUpdated
}
