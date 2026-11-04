package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

import com.prmteam7.podcasthistory.config.PackageFeatures;
import com.prmteam7.podcasthistory.dto.request.AdminRequests.ApproveWithdrawal;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class LegacyWithdrawalGuardTest {
  @Test
  void oldAdminEndpointsCannotApproveOrRejectAlreadyHeldPayout() {
    AdminSupportService support = mock(AdminSupportService.class);
    WithdrawalRequestRepository withdrawals = mock(WithdrawalRequestRepository.class);
    WalletTransactionRepository transactions = mock(WalletTransactionRepository.class);
    UserWalletRepository wallets = mock(UserWalletRepository.class);
    AdminFinanceService service = new AdminFinanceService(support, withdrawals,
        mock(WithdrawalReviewRepository.class), wallets, transactions,
        mock(PaymentRepository.class), mock(PaymentMethodRepository.class),
        mock(SubscriptionRepository.class), mock(AppUserRepository.class),
        mock(ContractRepository.class), mock(PackageFeatures.class),
        mock(AudienceNotificationService.class), mock(MembershipRevenueService.class),
        mock(WalletTransactionRealtimePublisher.class));
    UUID id = UUID.randomUUID();
    UUID actor = UUID.randomUUID();
    WithdrawalRequest withdrawal = new WithdrawalRequest();
    withdrawal.setWithdrawalRequestId(id);
    withdrawal.setStatus("PENDING");
    when(withdrawals.lockById(id)).thenReturn(Optional.of(withdrawal));
    when(transactions.findFirstByWithdrawalRequest_WithdrawalRequestIdAndTransactionType(
        eq(id), eq("WITHDRAWAL_HOLD"))).thenReturn(Optional.of(new WalletTransaction()));

    assertThrows(ResourceConflictException.class, () -> service.approve(actor, id,
        new ApproveWithdrawal(true, "approved")));
    assertThrows(ResourceConflictException.class, () -> service.reject(actor, id, "rejected"));
    verifyNoInteractions(wallets);
  }
}
