package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import jakarta.persistence.EntityManager;
import jakarta.persistence.Query;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class AdminDashboardPremiumRevenueTest {
  @Test
  void paidCreatorCheckoutAppearsInRevenueHistoryAndTotals() {
    AdminSupportService support = mock(AdminSupportService.class);
    AppUserRepository users = mock(AppUserRepository.class);
    ProducerProfileRepository creators = mock(ProducerProfileRepository.class);
    PodcastRepository podcasts = mock(PodcastRepository.class);
    ReportRepository reports = mock(ReportRepository.class);
    WithdrawalRequestRepository withdrawals = mock(WithdrawalRequestRepository.class);
    ContractDisputeRepository disputes = mock(ContractDisputeRepository.class);
    PaymentRepository payments = mock(PaymentRepository.class);
    WalletTransactionRepository walletTransactions = mock(WalletTransactionRepository.class);
    ContractRepository contracts = mock(ContractRepository.class);
    CheckoutPaymentRepository checkouts = mock(CheckoutPaymentRepository.class);
    EntityManager entityManager = mock(EntityManager.class);
    Query query = mock(Query.class);
    AdminDashboardService service = new AdminDashboardService(support, users, creators,
        podcasts, reports, withdrawals, disputes, payments, walletTransactions, contracts,
        checkouts, entityManager);

    UUID checkoutId = UUID.randomUUID();
    AppUser buyer = new AppUser();
    buyer.setUserId(UUID.randomUUID());
    buyer.setDisplayName("Creator");
    ProducerProfile profile = new ProducerProfile();
    profile.setUser(buyer);
    profile.setChannelName("Kênh A");
    CreatorSystemPlan plan = new CreatorSystemPlan();
    plan.setName("Studio Premium");
    CreatorSystemSubscription subscription = new CreatorSystemSubscription();
    subscription.setPlan(plan);
    subscription.setProducerProfile(profile);
    CheckoutPayment checkout = new CheckoutPayment();
    checkout.setCheckoutId(checkoutId);
    checkout.setCreatorSubscription(subscription);
    checkout.setUser(buyer);
    checkout.setPurpose("CREATOR_PLAN");
    checkout.setAmount(new BigDecimal("50000.00"));
    checkout.setCurrency("VND");
    checkout.setStatus("PAID");
    checkout.setPaidAt(Instant.parse("2026-11-04T00:00:00Z"));

    when(entityManager.createNativeQuery(anyString())).thenReturn(query);
    when(query.setFirstResult(0)).thenReturn(query);
    when(query.setMaxResults(20)).thenReturn(query);
    when(query.getResultList()).thenReturn(List.<Object[]>of(new Object[] {checkoutId, "CREATOR_PLAN"}));
    when(payments.findAllById(anyList())).thenReturn(List.of());
    when(checkouts.findAllById(anyList())).thenReturn(List.of(checkout));
    when(checkouts.countByPurposeAndStatusIn(eq("CREATOR_PLAN"), anyCollection())).thenReturn(1L);
    when(payments.collectedByCurrency()).thenReturn(List.of());
    when(checkouts.collectedCreatorPlansByCurrency())
        .thenReturn(List.<Object[]>of(new Object[] {"VND", new BigDecimal("50000.00")}));
    when(walletTransactions.platformFeesByCurrency()).thenReturn(List.of());
    when(podcasts.countsByStatus()).thenReturn(List.of());

    var history = service.revenueDetails(UUID.randomUUID(), 0, 20);
    assertEquals(1, history.getTotalElements());
    var detail = history.getContent().get(0);
    assertEquals("CREATOR_PLAN", detail.sourceType());
    assertEquals(checkoutId, detail.checkoutId());
    assertNull(detail.paymentId());
    assertEquals(new BigDecimal("50000.00"), detail.platformFee());
    assertEquals(BigDecimal.ZERO, detail.creatorNetAmount());
    assertEquals("Kênh A", detail.creatorChannelName());

    var dashboard = service.dashboard(UUID.randomUUID());
    assertEquals(new BigDecimal("50000.00"), dashboard.collectedPayments().get(0).amount());
    assertEquals(new BigDecimal("50000.00"), dashboard.revenueBreakdown().get(0).grossCollected());
    assertEquals(new BigDecimal("50000.00"), dashboard.revenueBreakdown().get(0).platformFees());
  }
}
