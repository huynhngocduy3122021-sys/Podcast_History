import axios, { AxiosHeaders } from 'axios'
import type { InternalAxiosRequestConfig } from 'axios'
import { tokenSchema, meSchema } from './contracts'
import type { Tokens, User } from './contracts'
import { isRole } from './permissions'
import { singleFlight, needsRefresh } from './refresh'
import { apiHeaders } from './api-config'
import { errorMessage } from './api-error'
export { errorMessage } from './api-error'

const baseURL = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:8081').replace(/\/$/, '')
const headers = apiHeaders(baseURL)
// No auth interceptors on this transport: refresh/login cannot recursively refresh.
const authApi = axios.create({ baseURL, timeout: 15000, headers })
export const api = axios.create({ baseURL, timeout: 15000, headers })
const storageKey = 'vietcast.admin.refresh'
let tokens: Tokens | null = null
let revision = 0
let user: User | null = null
let sessionError: string | null = null
const listeners = new Set<() => void>()
let volatileRefresh: string | null = null

function storedRefresh() {
  try { return sessionStorage.getItem(storageKey) || volatileRefresh } catch { return volatileRefresh }
}
function saveRefresh(value: string | null) {
  volatileRefresh = value
  try {
    if (value) sessionStorage.setItem(storageKey, value)
    else sessionStorage.removeItem(storageKey)
  } catch { /* Storage unavailable: this session stays in memory. */ }
}
function publish(next: User | null) {
  user = next
  if (next) sessionError = null
  listeners.forEach(listener => listener())
}
function clear(message: string | null = null) {
  revision++
  tokens = null
  saveRefresh(null)
  sessionError = message
  publish(null)
}
async function accept(value: unknown, expectedRevision: number) {
  const next = tokenSchema.parse(value)
  if (expectedRevision !== revision) throw new Error('Phiên đăng nhập đã thay đổi.')
  if (!isRole(next.user.role)) {
    await authApi.post('/api/auth/logout', { refreshToken: next.refreshToken }).catch(() => undefined)
    throw new Error('Chỉ ADMIN và STAFF được truy cập trang quản trị.')
  }
  tokens = next
  saveRefresh(next.refreshToken)
  // Role is only published after Backend validates /me.
  return next
}
async function verify(expectedRevision: number) {
  const me = meSchema.parse((await authApi.get('/api/auth/me', {
    headers: { Authorization: `Bearer ${tokens?.accessToken}` },
  })).data)
  if (expectedRevision !== revision || !tokens) throw new Error('Phiên đăng nhập đã thay đổi.')
  if (!isRole(me.role) || me.userId !== tokens.user.id) throw new Error('Phiên không hợp lệ cho trang quản trị.')
  publish({ ...tokens.user, id: me.userId, username: me.username, email: me.email, role: me.role })
}
const refreshSession = singleFlight(async () => {
  const expectedRevision = revision
  const refreshToken = storedRefresh()
  if (!refreshToken) throw new Error('Phiên đã hết hạn. Vui lòng đăng nhập lại.')
  try {
    await accept((await authApi.post('/api/auth/refresh', { refreshToken })).data, expectedRevision)
    await verify(expectedRevision)
  } catch (error) {
    if (expectedRevision === revision) clear(errorMessage(error))
    throw error
  }
})

type RetriedConfig = InternalAxiosRequestConfig & { _retried?: boolean; _sentToken?: string; _revision?: number }
api.interceptors.request.use((config: RetriedConfig) => {
  config._sentToken = tokens?.accessToken
  config._revision = revision
  config.headers = AxiosHeaders.from(config.headers)
  if (tokens) config.headers.set('Authorization', `Bearer ${tokens.accessToken}`)
  return config
})
api.interceptors.response.use(response => response, async (error: unknown) => {
  if (!axios.isAxiosError(error)) throw error
  const config = error.config as RetriedConfig | undefined
  if (error.response?.status !== 401 || !config) throw error
  if (config._revision !== revision) throw error
  if (config._retried) {
    // A retry for an older token must not invalidate a newer, verified session.
    if (config._sentToken === tokens?.accessToken) clear('Phiên đã hết hạn. Vui lòng đăng nhập lại.')
    throw error
  }
  config._retried = true
  if (needsRefresh(config._sentToken, tokens?.accessToken)) await refreshSession()
  if (config._revision !== revision || !tokens) throw error
  return api.request(config)
})

export const session = {
  getUser: () => user,
  getError: () => sessionError,
  subscribe(listener: () => void) { listeners.add(listener); return () => { listeners.delete(listener) } },
  async initialize() {
    if (!storedRefresh()) return
    await refreshSession()
  },
  async login(body: { identifier: string; password: string }) {
    clear()
    const expectedRevision = revision
    try {
      await accept((await authApi.post('/api/auth/login', body)).data, expectedRevision)
      await verify(expectedRevision)
    } catch (error) { if (expectedRevision === revision) clear(); throw error }
  },
  async logout() {
    // Backend revokes the entire family even if this token has just been rotated.
    const refreshToken = storedRefresh()
    clear()
    if (refreshToken) {
      const response = await authApi.post('/api/auth/logout', { refreshToken })
      if (response.status !== 204) throw new Error('Chưa xác nhận được việc thu hồi phiên trên máy chủ. Vui lòng thử lại sau.')
    }
  },
}

