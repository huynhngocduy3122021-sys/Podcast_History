package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class MembershipRevenueServiceTest {
  @Test
  void creditsEightyPercentOnceAndRecordsPlatformFee() {
    AppUserRepository users = mock(AppUserRepository.class);
    UserWalletRepository wallets = mock(UserWalletRepository.class);
    WalletTransactionRepository transactions = mock(WalletTransactionRepository.class);
    MembershipRevenueService service = new MembershipRevenueService(users, wallets, transactions,
        mock(WalletTransactionRealtimePublisher.class));
    AppUser creator = new AppUser();
    creator.setUserId(UUID.randomUUID());
    ProducerProfile profile = new ProducerProfile();
    profile.setUser(creator);
    MembershipPlan plan = new MembershipPlan();
    plan.setProducerProfile(profile);
    Subscription subscription = new Subscription();
    subscription.setMembershipPlan(plan);
    Payment payment = new Payment();
    payment.setPaymentId(UUID.randomUUID());
    payment.setSubscription(subscription);
    payment.setStatus("PAID");
    payment.setCurrency("VND");
    payment.setAmount(new BigDecimal("25000.00"));
    UserWallet wallet = new UserWallet();
    wallet.setUser(creator);
    wallet.setBalance(BigDecimal.ZERO);
    wallet.setHeldBalance(BigDecimal.ZERO);
    wallet.setCurrency("VND");
    wallet.setStatus("ACTIVE");
    when(users.findByIdForUpdate(creator.getUserId())).thenReturn(Optional.of(creator));
    when(wallets.findByUserIdForUpdate(creator.getUserId())).thenReturn(Optional.of(wallet));

    service.creditPaidMembership(payment);

    assertEquals(new BigDecimal("20000.00"), wallet.getBalance());
    ArgumentCaptor<WalletTransaction> saved = ArgumentCaptor.forClass(WalletTransaction.class);
    verify(transactions, times(2)).save(saved.capture());
    assertEquals("MEMBERSHIP_EARNING", saved.getAllValues().get(0).getTransactionType());
    assertEquals(new BigDecimal("20000.00"), saved.getAllValues().get(0).getAmount());
    assertEquals("PLATFORM_FEE", saved.getAllValues().get(1).getTransactionType());
    assertEquals(new BigDecimal("5000.00"), saved.getAllValues().get(1).getAmount());

    when(transactions.existsByPayment_PaymentIdAndTransactionType(payment.getPaymentId(),
        "MEMBERSHIP_EARNING")).thenReturn(true);
    service.creditPaidMembership(payment);
    assertEquals(new BigDecimal("20000.00"), wallet.getBalance());
    verify(transactions, times(2)).save(any(WalletTransaction.class));
  }
}
