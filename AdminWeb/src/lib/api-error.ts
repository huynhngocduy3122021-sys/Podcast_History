import axios from 'axios'
import { z } from 'zod'

const apiErrorSchema = z.object({ status: z.number().int(), error: z.string(), message: z.string(), timestamp: z.string() })
export type ApiFailure = { message: string; status?: number; fieldErrors: Record<string, string>; outcomeUnknown?: boolean }
export class UnconfirmedMutationError extends Error {
  constructor() {
    super('Chưa xác nhận được kết quả thao tác. Vui lòng tải lại dữ liệu để kiểm tra trước khi thử lại.')
    this.name = 'UnconfirmedMutationError'
  }
}
const fallbacks: Record<number, string> = {
  400: 'Dữ liệu gửi lên không hợp lệ.',
  401: 'Phiên đã hết hạn. Vui lòng đăng nhập lại.',
  403: 'Bạn không có quyền thực hiện thao tác này.',
  404: 'Không tìm thấy dữ liệu. Hồ sơ hoặc danh mục có thể đã thay đổi.',
  409: 'Dữ liệu trùng hoặc đã được xử lý. Tải lại để xem trạng thái mới nhất.',
  502: 'Không thể tạo liên kết media lúc này. Vui lòng thử lại sau.',
  503: 'Tính năng media hiện chưa khả dụng. Vui lòng thử lại sau hoặc liên hệ quản trị viên.',
}

export function extractApiError(error: unknown): ApiFailure {
  if (error instanceof UnconfirmedMutationError) return { message: error.message, fieldErrors: {}, outcomeUnknown: true }
  if (axios.isAxiosError(error)) {
    if (!error.response) return { message: 'Không thể kết nối. Vui lòng kiểm tra mạng và thử lại.', fieldErrors: {} }
    const status = error.response.status
    const parsed = apiErrorSchema.safeParse(error.response.data)
    // Display verified business errors only; do not expose arbitrary server exceptions.
    const login = error.config?.url?.split('?')[0].endsWith('/api/auth/login')
    // The login business message is deliberately generic about credentials/account state.
    const safeLoginMessage = 'Username/email hoặc mật khẩu không đúng, hoặc tài khoản đã bị khóa.'
    if (status === 401 && login) return {
      status, fieldErrors: {},
      message: parsed.success && parsed.data.status === status && parsed.data.message === safeLoginMessage
        ? parsed.data.message : 'Không thể đăng nhập. Vui lòng kiểm tra thông tin đăng nhập và thử lại.',
    }
    // Backend 502/503 messages may mention R2 configuration or infrastructure details.
    // Keep those details out of the UI while retaining an actionable fallback.
    const message = status === 502 || status === 503
      ? fallbacks[status]
      : status !== 401 && status in fallbacks && parsed.success && parsed.data.status === status && parsed.data.message.trim()
        ? parsed.data.message : fallbacks[status] || 'Không thể hoàn tất yêu cầu. Vui lòng thử lại.'
    const fieldErrors: Record<string, string> = {}
    // ApiError has no field map. Only exact messages verified in CategoryService identify a field.
    if (status === 409 && message === 'Tên category đã được sử dụng.') fieldErrors.name = message
    if (status === 409 && message === 'Slug category đã được sử dụng.') fieldErrors.slug = message
    if (status === 400 && message === 'Slug category không hợp lệ.') fieldErrors.slug = message
    return { status, message, fieldErrors }
  }
  if (error instanceof Error && !('issues' in error)) return { message: error.message, fieldErrors: {} }
  return { message: 'Chưa nhận được dữ liệu hợp lệ. Vui lòng tải lại hoặc thử lại sau.', fieldErrors: {} }
}

export function errorMessage(error: unknown): string { return extractApiError(error).message }
