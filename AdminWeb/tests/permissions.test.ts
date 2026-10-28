import test from 'node:test'
import assert from 'node:assert/strict'
import { apiPrefix, canAccess, isRole, sections } from '../src/lib/permissions.ts'

test('only ADMIN and STAFF enter the workspace', () => {
  for (const role of ['LISTENER', 'CREATOR', 'admin', '', null, undefined]) {
    assert.equal(canAccess(role), false)
    assert.equal(isRole(role), false)
  }
  assert.equal(canAccess('ADMIN'), true)
  assert.equal(canAccess('STAFF'), true)
})
test('STAFF has only supported moderation routes and personal notifications', () => {
  const paths = sections.filter(s => canAccess('STAFF', 'adminOnly' in s && s.adminOnly)).map(s => s.path)
  assert.deepEqual(paths, ['/dashboard', '/podcast-moderation', '/reports', '/appeals', '/notifications'])
  assert.equal(canAccess('STAFF', true), false)
  assert.equal(canAccess('ADMIN', true), true)
})
test('ADMIN has all 17 unique destinations', () => {
  const paths = sections.filter(s => canAccess('ADMIN', 'adminOnly' in s && s.adminOnly)).map(s => s.path)
  assert.equal(paths.length, 17)
  assert.equal(new Set(paths).size, 17)
})
test('shared moderation routes use the admin prefix for both roles', () => {
  assert.equal(apiPrefix('ADMIN'), '/api/admin')
  assert.equal(apiPrefix('STAFF'), '/api/admin')
})
