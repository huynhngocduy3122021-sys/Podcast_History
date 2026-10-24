import type { WithdrawalStatus } from './admin-contracts.ts'

export type WithdrawalActionState = {
  status: WithdrawalStatus
  fundsReserved: boolean
}

export function canApproveWithdrawal(withdrawal: WithdrawalActionState) {
  return withdrawal.status === 'PENDING' && withdrawal.fundsReserved === false
}

export function canCompleteWithdrawal(withdrawal: WithdrawalActionState) {
  return withdrawal.status === 'PROCESSING' && withdrawal.fundsReserved === true
}
