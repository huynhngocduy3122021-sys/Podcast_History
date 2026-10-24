import test from 'node:test'
import assert from 'node:assert/strict'
import { AxiosError, AxiosHeaders } from 'axios'
import { extractApiError, errorMessage, UnconfirmedMutationError } from '../src/lib/api-error.ts'
import { z } from 'zod'

function failure(status: number, data: unknown, url?: string) {
  const config = { headers: new AxiosHeaders(), url }
  return new AxiosError('request failed', undefined, config, undefined, { status, data, statusText: '', headers: {}, config })
}
const body = (status: number, message: string) => ({ timestamp: new Date().toISOString(), status, error: 'Error', message })

test('verified 400, 403, 404 and 409 business messages stay visible', () => {
  for (const status of [400, 403, 404, 409]) {
    const parsed = extractApiError(failure(status, body(status, `business message ${status}`)))
    assert.equal(parsed.status, status)
    assert.equal(parsed.message, `business message ${status}`)
  }
})

test('only verified category messages map to fields; generic validation has no invented field', () => {
  assert.deepEqual(extractApiError(failure(409, body(409, 'Tên category đã được sử dụng.'))).fieldErrors, { name: 'Tên category đã được sử dụng.' })
  assert.deepEqual(extractApiError(failure(409, body(409, 'Slug category đã được sử dụng.'))).fieldErrors, { slug: 'Slug category đã được sử dụng.' })
  assert.deepEqual(extractApiError(failure(400, body(400, 'Slug category không hợp lệ.'))).fieldErrors, { slug: 'Slug category không hợp lệ.' })
  assert.deepEqual(extractApiError(failure(400, body(400, 'must not be blank'))).fieldErrors, {})
})

test('malformed responses, 401, 500 and HTML never expose arbitrary server data', () => {
  for (const status of [401, 500]) assert.equal(errorMessage(failure(status, body(status, 'private diagnostic'))).includes('private diagnostic'), false)
  assert.equal(errorMessage(failure(403, '<html>private diagnostic</html>')).includes('private diagnostic'), false)
  assert.match(errorMessage(failure(403, undefined)), /không có quyền/)
  assert.equal(errorMessage(failure(400, body(500, 'private diagnostic'))).includes('private diagnostic'), false)
  assert.match(errorMessage(new AxiosError('network')), /Không thể kết nối/)
  const invalid = z.string().safeParse(5)
  if (!invalid.success) assert.match(errorMessage(invalid.error), /Chưa nhận được dữ liệu hợp lệ/)
})

test('502/503 media failures use safe actionable fallbacks for complete and malformed bodies', () => {
  for (const status of [502, 503]) {
    const privateMessage = 'Cloudflare R2 secret endpoint Backend/.env access key'
    const safe = errorMessage(failure(status, body(status, privateMessage)))
    const malformed = errorMessage(failure(status, '<html>private infrastructure diagnostic</html>'))
    assert.match(safe, /media/)
    assert.match(malformed, /media/)
    assert.equal(safe.includes('R2'), false)
    assert.equal(safe.includes('Backend/.env'), false)
    assert.equal(malformed.includes('private'), false)
  }
})

test('login 401 preserves the verified credential error, not the expired-session message', () => {
  const message = 'Username/email hoặc mật khẩu không đúng, hoặc tài khoản đã bị khóa.'
  assert.equal(errorMessage(failure(401, body(401, message), '/api/auth/login')), message)
  assert.equal(errorMessage(failure(401, body(401, message), 'https://example.invalid/api/auth/login?test=1')), message)
  for (const data of [undefined, '<html>private diagnostic</html>', body(401, 'private diagnostic'), body(500, message)]) {
    assert.equal(errorMessage(failure(401, data, '/api/auth/login')), 'Không thể đăng nhập. Vui lòng kiểm tra thông tin đăng nhập và thử lại.')
  }
  assert.equal(errorMessage(failure(401, body(401, message), '/api/auth/refresh')), 'Phiên đã hết hạn. Vui lòng đăng nhập lại.')
})

test('uncertain writes give a check-data instruction without claiming success or exposing diagnostics', () => {
  const failure = extractApiError(new UnconfirmedMutationError())
  assert.equal(failure.outcomeUnknown, true)
  assert.equal(failure.message, 'Chưa xác nhận được kết quả thao tác. Vui lòng tải lại dữ liệu để kiểm tra trước khi thử lại.')
  assert.deepEqual(failure.fieldErrors, {})
})
