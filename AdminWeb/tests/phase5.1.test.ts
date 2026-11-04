import test from 'node:test'
import assert from 'node:assert/strict'
import { formatMoney } from '../src/lib/finance-format.ts'
import { canApproveWithdrawal, canCompleteWithdrawal } from '../src/lib/withdrawal-rules.ts'

test('withdrawal actions follow Backend status and fundsReserved rules', () => {
  const combinations = [
    { status: 'PENDING' as const, fundsReserved: false, approve: true, complete: false },
    { status: 'PENDING' as const, fundsReserved: true, approve: false, complete: false },
    { status: 'PROCESSING' as const, fundsReserved: false, approve: false, complete: false },
    { status: 'PROCESSING' as const, fundsReserved: true, approve: false, complete: true },
  ]

  for (const combination of combinations) {
    assert.equal(canApproveWithdrawal(combination), combination.approve)
    assert.equal(canCompleteWithdrawal(combination), combination.complete)
  }
})

test('financial formatter preserves exact decimal strings without Number conversion', () => {
  const cases = [
    ['9007199254740993', '9.007.199.254.740.993'],
    ['12345678901234567890.123456789', '12.345.678.901.234.567.890,123456789'],
    ['0.00000001', '0,00000001'],
    ['-12345.67', '-12.345,67'],
    ['0', '0'],
  ] as const

  for (const [input, expected] of cases) {
    assert.match(formatMoney(input, 'VND'), new RegExp(expected.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')))
  }
})

test('financial formatter handles optional and malformed values visibly', () => {
  assert.equal(formatMoney(undefined, 'VND'), '—')
  assert.equal(formatMoney(null, 'VND'), '—')
  assert.equal(formatMoney('', 'VND'), '—')
  assert.equal(formatMoney('not-a-number', 'VND'), 'not-a-number VND')
  assert.equal(formatMoney('12.3.4', 'VND'), '12.3.4 VND')
})
