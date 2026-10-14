import test from 'node:test'
import assert from 'node:assert/strict'
import { singleFlight, needsRefresh } from '../src/lib/refresh.ts'

test('concurrent refreshes share one rotation and the same result', async () => {
  let calls = 0
  let release!: (value: string) => void
  const gate = new Promise<string>(resolve => { release = resolve })
  const refresh = singleFlight(async () => { calls++; return gate })
  const pending = Array.from({ length: 20 }, () => refresh())
  await Promise.resolve()
  assert.equal(calls, 1)
  assert.ok(pending.every(p => p === pending[0]))
  release('rotated-token')
  assert.deepEqual(await Promise.all(pending), Array(20).fill('rotated-token'))
})
test('failed refresh rejects every waiter and permits a later operation', async () => {
  let calls = 0
  const refresh = singleFlight(async () => {
    calls++
    if (calls === 1) throw new Error('revoked')
    return 'new-session'
  })
  const failures = await Promise.allSettled([refresh(), refresh(), refresh()])
  assert.equal(calls, 1)
  assert.ok(failures.every(result => result.status === 'rejected'))
  assert.equal(await refresh(), 'new-session')
  assert.equal(calls, 2)
})
test('successful refresh clears the gate for a later token expiry', async () => {
  let rotations = 0
  const refresh = singleFlight(async () => ++rotations)
  assert.equal(await refresh(), 1)
  assert.equal(await refresh(), 2)
})
test('a late 401 reuses a rotated token instead of refreshing again', () => {
  assert.equal(needsRefresh('old', 'rotated'), false)
  assert.equal(needsRefresh('current', 'current'), true)
  assert.equal(needsRefresh('expired', undefined), true)
})
