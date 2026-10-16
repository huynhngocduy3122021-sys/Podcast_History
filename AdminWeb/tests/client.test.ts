import test from 'node:test'
import type { TestContext } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { stripTypeScriptTypes } from 'node:module'
import { randomUUID } from 'node:crypto'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'
import axios, { AxiosError } from 'axios'
import type { AxiosResponse, InternalAxiosRequestConfig } from 'axios'

const user = { id: '11111111-1111-4111-8111-111111111111', username: 'test-admin', email: 'test@example.invalid', displayName: null, role: 'ADMIN' }
const me = { userId: user.id, username: user.username, email: user.email, role: user.role }
const login = { identifier: 'mock-account', password: 'mock-password' }
const pair = () => ({ accessToken: randomUUID(), refreshToken: randomUUID(), tokenType: 'Bearer', expiresIn: 600, refreshExpiresIn: 604800, user })
const response = (config: InternalAxiosRequestConfig, data: unknown, status = 200): AxiosResponse => ({ config, data, status, statusText: '', headers: {} })
function httpError(config: InternalAxiosRequestConfig, status: number) {
  return new AxiosError('mock HTTP error', undefined, config, undefined, response(config, {
    timestamp: new Date().toISOString(), status, error: 'Error', message: 'private diagnostic',
  }, status))
}
function deferred() {
  let resolve!: () => void
  const promise = new Promise<void>(done => { resolve = done })
  return { promise, resolve }
}

type Handler = (config: InternalAxiosRequestConfig) => Promise<AxiosResponse | undefined> | AxiosResponse | undefined
async function mockClient(t: TestContext, handler: Handler = () => undefined) {
  const oldAdapter = axios.defaults.adapter
  const storageDescriptor = Object.getOwnPropertyDescriptor(globalThis, 'sessionStorage')
  const storage = new Map<string, string>()
  Object.defineProperty(globalThis, 'sessionStorage', { configurable: true, value: {
    getItem: (key: string) => storage.get(key) ?? null,
    setItem: (key: string, value: string) => storage.set(key, value),
    removeItem: (key: string) => storage.delete(key),
  } })
  const calls: InternalAxiosRequestConfig[] = []
  axios.defaults.adapter = async config => {
    calls.push(config)
    const custom = await handler(config)
    if (custom) return custom
    switch (config.url) {
      case '/api/auth/login':
      case '/api/auth/refresh': return response(config, pair())
      case '/api/auth/me': return response(config, me)
      case '/api/auth/logout': return response(config, '', 204)
      default: throw new Error(`Unexpected mocked endpoint: ${config.url}`)
    }
  }
  t.after(() => {
    axios.defaults.adapter = oldAdapter
    if (storageDescriptor) Object.defineProperty(globalThis, 'sessionStorage', storageDescriptor)
    else Reflect.deleteProperty(globalThis, 'sessionStorage')
  })
  // Run the actual singleton and interceptors with an offline adapter. Replace only
  // Vite's env access and module URLs in memory; no production test hooks or files.
  const sourceUrl = pathToFileURL(resolve('src/lib/client.ts'))
  const source = stripTypeScriptTypes(readFileSync(sourceUrl, 'utf8'))
    .replace(/from (['"])axios\1/g, `from '${pathToFileURL(resolve('node_modules/axios/index.js')).href}'`)
    .replace(/(['"])(\.\/[^'"]+)\1/g, (_match, _quote, path: string) => JSON.stringify(new URL(path.endsWith('.ts') ? path : `${path}.ts`, sourceUrl).href))
    .replace('import.meta.env.VITE_API_BASE_URL', JSON.stringify('https://offline-test.invalid'))
  const client = await import(`data:text/javascript,${encodeURIComponent(`${source}\n// ${randomUUID()}`)}`) as typeof import('../src/lib/client.ts')
  return { ...client, calls, storage }
}

test('actual interceptors share one refresh for concurrent 401s and retry each request once', async t => {
  const gate = deferred()
  const started = deferred()
  const client = await mockClient(t, async config => {
    if (config.url === '/api/auth/refresh') { started.resolve(); await gate.promise }
    if (config.url?.startsWith('/protected/')) {
      if (config.headers.get('Authorization') === token) throw httpError(config, 401)
      return response(config, { ok: true })
    }
  })
  await client.session.login(login)
  const token = String(client.calls.find(call => call.url === '/api/auth/me')?.headers.get('Authorization'))
  const pending = Array.from({ length: 4 }, (_, i) => client.api.get(`/protected/${i}`))
  await started.promise
  gate.resolve()
  await Promise.all(pending)
  assert.equal(client.calls.filter(c => c.url === '/api/auth/refresh').length, 1)
  for (let i = 0; i < 4; i++) assert.equal(client.calls.filter(c => c.url === `/protected/${i}`).length, 2)
  assert.equal(client.session.getUser()?.id, user.id)
})

test('a late 401 from an old retry cannot clear a newer verified session', async t => {
  const retryStarted = deferred()
  const releaseRetry = deferred()
  const attempts = new Map<string, number>()
  const client = await mockClient(t, async config => {
    if (config.url !== '/protected/old' && config.url !== '/protected/new') return
    const count = (attempts.get(config.url) ?? 0) + 1
    attempts.set(config.url, count)
    if (count === 1) throw httpError(config, 401)
    if (config.url === '/protected/old') {
      retryStarted.resolve()
      await releaseRetry.promise
      throw httpError(config, 401)
    }
    return response(config, { ok: true })
  })
  await client.session.login(login)
  const oldRequest = assert.rejects(client.api.get('/protected/old'), AxiosError)
  await retryStarted.promise
  await client.api.get('/protected/new')
  assert.equal(client.calls.filter(c => c.url === '/api/auth/refresh').length, 2)
  releaseRetry.resolve()
  await oldRequest
  assert.equal(client.session.getUser()?.id, user.id)
  assert.equal(client.session.getError(), null)
  assert.equal(attempts.get('/protected/old'), 2)
})

test('401 on the current retry expires the session and retains a safe reason for the login page', async t => {
  const client = await mockClient(t, config => {
    if (config.url === '/protected') throw httpError(config, 401)
    return undefined
  })
  await client.session.login(login)
  await assert.rejects(client.api.get('/protected'), AxiosError)
  assert.equal(client.calls.filter(c => c.url === '/protected').length, 2)
  assert.equal(client.calls.filter(c => c.url === '/api/auth/refresh').length, 1)
  assert.equal(client.session.getUser(), null)
  assert.equal(client.storage.size, 0)
  assert.equal(client.session.getError(), 'Phiên đã hết hạn. Vui lòng đăng nhập lại.')
  await client.session.login(login)
  assert.equal(client.session.getError(), null)
})

test('refresh failure clears the session once; a successful login removes the stale error', async t => {
  const client = await mockClient(t, config => {
    if (config.url === '/protected' || config.url === '/api/auth/refresh') throw httpError(config, 401)
    return undefined
  })
  await client.session.login(login)
  await assert.rejects(client.api.get('/protected'), AxiosError)
  assert.equal(client.calls.filter(c => c.url === '/protected').length, 1)
  assert.equal(client.calls.filter(c => c.url === '/api/auth/refresh').length, 1)
  assert.equal(client.session.getUser(), null)
  assert.equal(client.session.getError()?.includes('private diagnostic'), false)
  assert.equal(client.storage.size, 0)
  await client.session.login(login)
  assert.equal(client.session.getError(), null)
  await client.session.logout()
  assert.equal(client.session.getError(), null)
})

test('403 does not refresh or sign out the current user', async t => {
  const client = await mockClient(t, config => {
    if (config.url === '/protected') throw httpError(config, 403)
    return undefined
  })
  await client.session.login(login)
  await assert.rejects(client.api.get('/protected'), AxiosError)
  assert.equal(client.calls.filter(c => c.url === '/api/auth/refresh').length, 0)
  assert.equal(client.session.getUser()?.id, user.id)
})

test('logout during refresh prevents an in-flight result from restoring the session', async t => {
  const started = deferred()
  const release = deferred()
  const client = await mockClient(t, async config => {
    if (config.url === '/protected') throw httpError(config, 401)
    if (config.url === '/api/auth/refresh') { started.resolve(); await release.promise }
    return undefined
  })
  await client.session.login(login)
  const pending = assert.rejects(client.api.get('/protected'))
  await started.promise
  await client.session.logout()
  release.resolve()
  await pending
  assert.equal(client.session.getUser(), null)
  assert.equal(client.session.getError(), null)
  assert.equal(client.storage.size, 0)
  assert.equal(client.calls.filter(c => c.url === '/protected').length, 1)
})

test('unsupported roles and malformed /me never publish a session', async t => {
  let wrongRole = true
  const client = await mockClient(t, config => {
    if (config.url === '/api/auth/login' && wrongRole) return response(config, { ...pair(), user: { ...user, role: 'LISTENER' } })
    if (config.url === '/api/auth/me') return response(config, { ...me, userId: 'another-user' })
  })
  await assert.rejects(client.session.login(login), /ADMIN và STAFF/)
  assert.equal(client.calls.filter(c => c.url === '/api/auth/logout').length, 1)
  assert.equal(client.session.getUser(), null)
  wrongRole = false
  await assert.rejects(client.session.login(login), /Phiên không hợp lệ/)
  assert.equal(client.session.getUser(), null)
  assert.equal(client.storage.size, 0)
})

test('logout only confirms the verified 204 response and keeps local logout on an unexpected response', async t => {
  let status = 204
  const client = await mockClient(t, config => {
    if (config.url === '/api/auth/logout') return response(config, '', status)
  })
  await client.session.login(login)
  await client.session.logout()
  assert.equal(client.session.getUser(), null)
  await client.session.login(login)
  status = 200
  await assert.rejects(client.session.logout(), /Chưa xác nhận được việc thu hồi phiên/)
  assert.equal(client.session.getUser(), null)
  assert.equal(client.storage.size, 0)
})
