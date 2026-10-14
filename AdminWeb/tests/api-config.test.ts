import test from 'node:test'
import assert from 'node:assert/strict'
import { apiHeaders } from '../src/lib/api-config.ts'

test('ngrok dev and app domains bypass the browser interstitial', () => {
  for (const host of ['example.ngrok-free.dev', 'example.ngrok-free.app', 'example.ngrok.app', 'example.ngrok.io']) {
    assert.equal(apiHeaders(`https://${host}`)['ngrok-skip-browser-warning'], 'true')
  }
})
test('local and unrelated servers do not get the ngrok header', () => {
  for (const url of ['http://localhost:8081', 'https://api.example.com', 'https://ngrok-free.dev.example.com']) {
    assert.deepEqual(apiHeaders(url), { Accept: 'application/json' })
  }
})
