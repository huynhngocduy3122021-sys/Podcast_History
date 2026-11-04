package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import com.prmteam7.podcasthistory.config.PackageFeatures;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class CreatorSystemPlanWalletPaymentTest {
  @Test
  void paysExactPlanPriceAndRecordsWalletDebit() {
    Fixture f = new Fixture(new BigDecimal("100000"));

    var result = f.service.subscribeWithWallet(f.userId, f.planId);

    assertEquals("PAID", result.status());
    assertEquals(new BigDecimal("50000"), f.wallet.getBalance());
    ArgumentCaptor<WalletTransaction> tx = ArgumentCaptor.forClass(WalletTransaction.class);
    verify(f.transactions).save(tx.capture());
    assertEquals("CREATOR_PLAN_PURCHASE", tx.getValue().getTransactionType());
    assertEquals(new BigDecimal("50000"), tx.getValue().getAmount());
    assertEquals(new BigDecimal("50000"), tx.getValue().getBalanceAfter());
    assertEquals("SUCCEEDED", f.savedSubscription.getPaymentStatus());
    verify(f.realtime).changed(f.wallet);
  }

  @Test
  void insufficientBalanceCreatesNoSubscriptionOrDebit() {
    Fixture f = new Fixture(new BigDecimal("49999"));

    assertThrows(ResourceConflictException.class,
        () -> f.service.subscribeWithWallet(f.userId, f.planId));

    assertEquals(new BigDecimal("49999"), f.wallet.getBalance());
    verify(f.subscriptions, never()).saveAndFlush(any());
    verify(f.transactions, never()).save(any());
  }

  @Test
  void activeSubscriptionCannotBePurchasedTwice() {
    Fixture f = new Fixture(new BigDecimal("100000"));
    when(f.subscriptions
        .findTopByProducerProfile_ProducerProfileIdAndPaymentStatusAndStartAtLessThanEqualAndEndAtAfterOrderByEndAtDesc(
            eq(f.profileId), eq("SUCCEEDED"), any(Instant.class), any(Instant.class)))
        .thenReturn(Optional.of(new CreatorSystemSubscription()));

    assertThrows(ResourceConflictException.class,
        () -> f.service.subscribeWithWallet(f.userId, f.planId));
    verify(f.wallets, never()).findByUserIdForUpdate(any());
  }

  @Test
  void pendingBankCheckoutBlocksWalletPaymentUntilCancelled() {
    Fixture f = new Fixture(new BigDecimal("100000"));
    when(f.subscriptions.existsByProducerProfile_ProducerProfileIdAndPaymentStatus(
        f.profileId, "PENDING")).thenReturn(true);

    assertThrows(ResourceConflictException.class,
        () -> f.service.subscribeWithWallet(f.userId, f.planId));

    assertEquals(new BigDecimal("100000"), f.wallet.getBalance());
    verify(f.transactions, never()).save(any());
  }

  private static final class Fixture {
    final UUID userId = UUID.randomUUID();
    final UUID profileId = UUID.randomUUID();
    final UUID planId = UUID.randomUUID();
    final CreatorSystemPlanRepository plans = mock(CreatorSystemPlanRepository.class);
    final CreatorSystemSubscriptionRepository subscriptions = mock(CreatorSystemSubscriptionRepository.class);
    final ProducerProfileRepository creators = mock(ProducerProfileRepository.class);
    final CheckoutPaymentRepository checkouts = mock(CheckoutPaymentRepository.class);
    final UserWalletRepository wallets = mock(UserWalletRepository.class);
    final WalletTransactionRepository transactions = mock(WalletTransactionRepository.class);
    final WalletTransactionRealtimePublisher realtime = mock(WalletTransactionRealtimePublisher.class);
    final UserWallet wallet = new UserWallet();
    final CreatorSystemPlanService service;
    CreatorSystemSubscription savedSubscription;

    Fixture(BigDecimal balance) {
      AppUser user = new AppUser();
      user.setUserId(userId);
      user.setIsActive(true);
      ProducerProfile profile = new ProducerProfile();
      profile.setProducerProfileId(profileId);
      profile.setUser(user);
      profile.setVerificationStatus("APPROVED");
      CreatorSystemPlan plan = new CreatorSystemPlan();
      plan.setPrice(new BigDecimal("50000"));
      plan.setCurrency("VND");
      plan.setStatus("ACTIVE");
      plan.setDurationDays(30);
      wallet.setUser(user);
      wallet.setBalance(balance);
      wallet.setHeldBalance(BigDecimal.ZERO);
      wallet.setCurrency("VND");
      wallet.setStatus("ACTIVE");
      when(creators.findByUserIdForUpdate(userId)).thenReturn(Optional.of(profile));
      when(plans.findById(planId)).thenReturn(Optional.of(plan));
      when(wallets.findByUserIdForUpdate(userId)).thenReturn(Optional.of(wallet));
      when(subscriptions.saveAndFlush(any())).thenAnswer(call -> {
        savedSubscription = call.getArgument(0);
        savedSubscription.setSubscriptionId(UUID.randomUUID());
        return savedSubscription;
      });
      when(checkouts.saveAndFlush(any())).thenAnswer(call -> {
        CheckoutPayment checkout = call.getArgument(0);
        checkout.setCheckoutId(UUID.randomUUID());
        return checkout;
      });
      service = new CreatorSystemPlanService(plans, subscriptions, creators,
          mock(PodcastRepository.class), mock(AdminSupportService.class),
          new PackageFeatures(true, true), checkouts, mock(SepayService.class),
          wallets, transactions, realtime);
    }
  }
}
