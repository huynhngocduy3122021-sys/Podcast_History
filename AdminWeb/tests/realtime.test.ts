import test from 'node:test'
import assert from 'node:assert/strict'
import { parseStompFrame, stompFrame } from '../src/lib/realtime-protocol.ts'

test('STOMP frames preserve headers, body and terminator', () => {
  const encoded = stompFrame('CONNECT', { Authorization: 'Bearer token', host: 'localhost' }, 'hello')
  assert.equal(encoded.endsWith('\0'), true)
  assert.deepEqual(parseStompFrame(encoded), {
    command: 'CONNECT',
    headers: { Authorization: 'Bearer token', host: 'localhost' },
    body: 'hello',
  })
})

test('STOMP parser ignores incomplete frames and tolerates broker heartbeats', () => {
  assert.equal(parseStompFrame('MESSAGE\ncontent-type:application/json\n'), null)
  assert.deepEqual(parseStompFrame('\nMESSAGE\ndestination:/user/queue/notifications\n\n{}\0'), {
    command: 'MESSAGE',
    headers: { destination: '/user/queue/notifications' },
    body: '{}',
  })
})
