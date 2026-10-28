import type { QueryClient } from '@tanstack/react-query'
import type { Contract, CreatorApplication, CreatorStatus, Dispute, Payment, Withdrawal } from './admin-contracts.ts'

export const adminKeys = {
  creators: (userId: string | undefined) => ['creator-applications', userId] as const,
  creatorList: (userId: string | undefined, status: CreatorStatus | '', page: number, size: number) => ['creator-applications', userId, 'list', status, page, size] as const,
  creatorDetail: (userId: string | undefined, applicationId: string | null) => ['creator-applications', userId, 'detail', applicationId] as const,
  categories: (userId: string | undefined) => ['categories', userId] as const,
  users: (userId: string | undefined) => ['admin-users', userId] as const,
  userList: (userId: string | undefined, q: string, role: string, active: string, page: number, size: number) => ['admin-users', userId, 'list', q, role, active, page, size] as const,
  userDetail: (userId: string | undefined, targetId: string | null) => ['admin-users', userId, 'detail', targetId] as const,
  staff: (userId: string | undefined, page: number, size: number) => ['admin-staff', userId, page, size] as const,
  plans: (userId: string | undefined) => ['membership-plans', userId] as const,
  planList: (userId: string | undefined, creatorId: string, status: string, page: number, size: number) => ['membership-plans', userId, 'list', creatorId, status, page, size] as const,
  planDetail: (userId: string | undefined, planId: string | null) => ['membership-plans', userId, 'detail', planId] as const,
  creatorSystemPlans: (userId: string | undefined) => ['creator-system-plans', userId] as const,
  creatorSystemPlanDetail: (userId: string | undefined, planId: string | null) => ['creator-system-plans', userId, 'detail', planId] as const,
  audits: (userId: string | undefined) => ['audit-logs', userId] as const,
  auditList: (userId: string | undefined, resourceType: string, resourceId: string, page: number, size: number) => ['audit-logs', userId, 'list', resourceType, resourceId, page, size] as const,
  payments: (userId: string | undefined) => ['payments', userId] as const,
  paymentList: (userId: string | undefined, status: string, page: number, size: number) => ['payments', userId, 'list', status, page, size] as const,
  paymentDetail: (userId: string | undefined, paymentId: string | null) => ['payments', userId, 'detail', paymentId] as const,
  withdrawals: (userId: string | undefined) => ['withdrawals', userId] as const,
  withdrawalList: (userId: string | undefined, status: string, page: number, size: number) => ['withdrawals', userId, 'list', status, page, size] as const,
  withdrawalDetail: (userId: string | undefined, withdrawalId: string | null) => ['withdrawals', userId, 'detail', withdrawalId] as const,
  withdrawalReviews: (userId: string | undefined, withdrawalId: string | null, page: number, size: number) => ['withdrawals', userId, 'reviews', withdrawalId, page, size] as const,
  wallets: (userId: string | undefined) => ['wallets', userId] as const,
  walletList: (userId: string | undefined, qOrPage: string | number, roleOrSize: string | number, page?: number, size?: number) => typeof qOrPage === 'number'
    ? ['wallets', userId, 'list', qOrPage, roleOrSize] as const
    : ['wallets', userId, 'list', qOrPage, roleOrSize, page, size] as const,
  walletTransactions: (userId: string | undefined, walletId: string, status: string, page: number, size: number) => ['wallet-transactions', userId, walletId, status, page, size] as const,
  contracts: (userId: string | undefined) => ['contracts', userId] as const,
  contractList: (userId: string | undefined, status: string, page: number, size: number) => ['contracts', userId, 'list', status, page, size] as const,
  contractDetail: (userId: string | undefined, contractId: string | null) => ['contracts', userId, 'detail', contractId] as const,
  disputes: (userId: string | undefined) => ['disputes', userId] as const,
  disputeList: (userId: string | undefined, status: string, page: number, size: number) => ['disputes', userId, 'list', status, page, size] as const,
  disputeDetail: (userId: string | undefined, disputeId: string | null) => ['disputes', userId, 'detail', disputeId] as const,
}

export async function creatorReviewConfirmed(client: QueryClient, userId: string | undefined, application: CreatorApplication) {
  client.setQueryData(adminKeys.creatorDetail(userId, application.applicationId), application)
  await Promise.all([
    client.invalidateQueries({ queryKey: adminKeys.creators(userId) }),
    client.invalidateQueries({ queryKey: ['dashboard', userId] }),
  ])
}

export async function categoryChangeConfirmed(client: QueryClient, userId: string | undefined) {
  await client.invalidateQueries({ queryKey: adminKeys.categories(userId) })
}

export async function userChangeConfirmed(client: QueryClient, userId: string | undefined, targetId?: string) {
  await Promise.all([
    client.invalidateQueries({ queryKey: adminKeys.users(userId) }),
    client.invalidateQueries({ queryKey: ['dashboard', userId] }),
    targetId ? client.invalidateQueries({ queryKey: adminKeys.userDetail(userId, targetId) }) : Promise.resolve(),
  ])
}

export async function staffChangeConfirmed(client: QueryClient, userId: string | undefined) {
  await Promise.all([
    client.invalidateQueries({ queryKey: ['admin-staff', userId] }),
    client.invalidateQueries({ queryKey: adminKeys.users(userId) }),
    client.invalidateQueries({ queryKey: ['dashboard', userId] }),
  ])
}

export async function planChangeConfirmed(client: QueryClient, userId: string | undefined, planId?: string) {
  await Promise.all([
    client.invalidateQueries({ queryKey: adminKeys.plans(userId) }),
    planId ? client.invalidateQueries({ queryKey: adminKeys.planDetail(userId, planId) }) : Promise.resolve(),
  ])
}

export async function creatorSystemPlanChangeConfirmed(client: QueryClient, userId: string | undefined, planId?: string) {
  await Promise.all([
    client.invalidateQueries({ queryKey: adminKeys.creatorSystemPlans(userId) }),
    planId ? client.invalidateQueries({ queryKey: adminKeys.creatorSystemPlanDetail(userId, planId) }) : Promise.resolve(),
  ])
}

export async function paymentChangeConfirmed(client: QueryClient, userId: string, payment?: Payment) {
  if (payment) client.setQueryData(adminKeys.paymentDetail(userId, payment.paymentId), payment)
  await Promise.all([
    client.invalidateQueries({ queryKey: adminKeys.payments(userId) }),
    client.invalidateQueries({ queryKey: ['dashboard', userId] }),
    payment ? client.invalidateQueries({ queryKey: adminKeys.paymentDetail(userId, payment.paymentId) }) : Promise.resolve(),
  ])
}

export async function financeChangeConfirmed(client: QueryClient, userId: string, withdrawal?: Withdrawal) {
  if (withdrawal) client.setQueryData(adminKeys.withdrawalDetail(userId, withdrawal.withdrawalId), withdrawal)
  await Promise.all([
    client.invalidateQueries({ queryKey: adminKeys.withdrawals(userId) }),
    client.invalidateQueries({ queryKey: adminKeys.wallets(userId) }),
    client.invalidateQueries({ queryKey: ['wallet-transactions', userId] }),
    client.invalidateQueries({ queryKey: ['dashboard', userId] }),
    withdrawal ? client.invalidateQueries({ queryKey: adminKeys.withdrawalDetail(userId, withdrawal.withdrawalId) }) : Promise.resolve(),
    withdrawal ? client.invalidateQueries({ queryKey: ['withdrawals', userId, 'reviews', withdrawal.withdrawalId] }) : Promise.resolve(),
  ])
}

export async function contractChangeConfirmed(client: QueryClient, userId: string, contract?: Contract) {
  if (contract) client.setQueryData(adminKeys.contractDetail(userId, contract.contractId), contract)
  await Promise.all([
    client.invalidateQueries({ queryKey: adminKeys.contracts(userId) }),
    client.invalidateQueries({ queryKey: adminKeys.disputes(userId) }),
    client.invalidateQueries({ queryKey: ['dashboard', userId] }),
    contract ? client.invalidateQueries({ queryKey: adminKeys.contractDetail(userId, contract.contractId) }) : Promise.resolve(),
  ])
}

export async function disputeChangeConfirmed(client: QueryClient, userId: string, dispute?: Dispute) {
  if (dispute) client.setQueryData(adminKeys.disputeDetail(userId, dispute.disputeId), dispute)
  await Promise.all([
    client.invalidateQueries({ queryKey: adminKeys.disputes(userId) }),
    client.invalidateQueries({ queryKey: adminKeys.contracts(userId) }),
    client.invalidateQueries({ queryKey: ['dashboard', userId] }),
    dispute ? client.invalidateQueries({ queryKey: adminKeys.disputeDetail(userId, dispute.disputeId) }) : Promise.resolve(),
    dispute ? client.invalidateQueries({ queryKey: adminKeys.contractDetail(userId, dispute.contractId) }) : Promise.resolve(),
  ])
}
