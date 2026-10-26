package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.prmteam7.podcasthistory.config.SepayProperties;
import com.prmteam7.podcasthistory.dto.request.SepayWebhookRequest;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.MembershipPlan;
import com.prmteam7.podcasthistory.model.Payment;
import com.prmteam7.podcasthistory.model.Subscription;
import com.prmteam7.podcasthistory.repository.PaymentRepository;
import com.prmteam7.podcasthistory.repository.SubscriptionRepository;
import java.math.BigDecimal;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class SepayServiceTest {
  @Mock private PaymentRepository paymentRepository;
  @Mock private SubscriptionRepository subscriptionRepository;

  private SepayProperties properties;
  private SepayService service;

  @BeforeEach
  void setUp() {
    properties = new SepayProperties();
    properties.setWebhookApiKey("test-sepay-api-key");
    properties.setAccountNumber("0123456789");
    properties.setBank("MB");
    properties.setPaymentCodePrefix("MEM");
    service = new SepayService(properties, paymentRepository, subscriptionRepository);
  }

  @Test
  void createPayment_generatesCodeAndVietQrUrl() {
    UUID userId = UUID.randomUUID();
    Payment payment = payment(userId, "PENDING", "100000");
    Subscription subscription = new Subscription();
    subscription.setSubscriptionId(UUID.randomUUID());
    subscription.setStatus("PENDING");
    payment.setSubscription(subscription);
    when(paymentRepository.lockById(payment.getPaymentId())).thenReturn(java.util.Optional.of(payment));
    when(paymentRepository.save(any(Payment.class))).thenAnswer(invocation -> invocation.getArgument(0));

    var response = service.createPayment(userId, payment.getPaymentId());

    assertTrue(response.paymentCode().matches("MEM-[A-F0-9]{24}"));
    assertTrue(response.qrUrl().startsWith("https://vietqr.app/img?"));
    assertTrue(response.qrUrl().contains("acc=0123456789"));
    assertTrue(response.qrUrl().contains("bank=MB"));
    assertTrue(response.qrUrl().contains("amount=100000"));
    assertTrue(response.qrUrl().contains("des=" + response.paymentCode()));
    assertEquals("SEPAY", payment.getProvider());
    assertEquals(response.paymentCode(), payment.getProviderTransactionId());
  }

  @Test
  void isAuthorized_rejectsWrongApiKey() {
    assertFalse(service.isAuthorized("Apikey wrong"));
    assertTrue(service.isAuthorized("Apikey test-sepay-api-key"));
  }

  @Test
  void processWebhook_validPaymentActivatesSubscriptionOnlyOnce() {
    UUID userId = UUID.randomUUID();
    Payment payment = payment(userId, "PENDING", "100000");
    payment.setProvider("SEPAY");
    payment.setProviderTransactionId("MEM-ABCD");
    Subscription subscription = new Subscription();
    subscription.setSubscriptionId(UUID.randomUUID());
    subscription.setStatus("PENDING");
    MembershipPlan plan = new MembershipPlan();
    plan.setDurationDays(30);
    subscription.setMembershipPlan(plan);
    payment.setSubscription(subscription);

    when(paymentRepository.findByProviderTransactionId("MEM-ABCD"))
        .thenReturn(java.util.Optional.of(payment));
    when(paymentRepository.lockById(payment.getPaymentId()))
        .thenReturn(java.util.Optional.of(payment));
    when(subscriptionRepository.lockById(subscription.getSubscriptionId()))
        .thenReturn(java.util.Optional.of(subscription));
    when(paymentRepository.save(any(Payment.class))).thenAnswer(invocation -> invocation.getArgument(0));
    when(subscriptionRepository.save(any(Subscription.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));

    SepayWebhookRequest request =
        new SepayWebhookRequest("MEM-ABCD", "in", new BigDecimal("100000.00"), "bank-ref-1");
    service.processWebhook(request);
    service.processWebhook(request);

    assertEquals("PAID", payment.getStatus());
    assertNotNull(payment.getPaidAt());
    assertEquals("ACTIVE", subscription.getStatus());
    assertNotNull(subscription.getStartAt());
    assertTrue(subscription.getEndAt().isAfter(subscription.getStartAt()));
    verify(subscriptionRepository, org.mockito.Mockito.times(1)).save(subscription);
  }

  @Test
  void processWebhook_amountMismatchDoesNotChangePayment() {
    UUID userId = UUID.randomUUID();
    Payment payment = payment(userId, "PENDING", "100000");
    payment.setProvider("SEPAY");
    payment.setProviderTransactionId("MEM-ABCD");
    when(paymentRepository.findByProviderTransactionId("MEM-ABCD"))
        .thenReturn(java.util.Optional.of(payment));
    when(paymentRepository.lockById(payment.getPaymentId()))
        .thenReturn(java.util.Optional.of(payment));

    service.processWebhook(
        new SepayWebhookRequest("MEM-ABCD", "IN", new BigDecimal("99999"), "bank-ref-2"));

    assertEquals("PENDING", payment.getStatus());
    verify(paymentRepository, never()).save(any(Payment.class));
  }

  private Payment payment(UUID userId, String status, String amount) {
    AppUser user = new AppUser();
    user.setUserId(userId);
    Payment payment = new Payment();
    payment.setPaymentId(UUID.randomUUID());
    payment.setUser(user);
    payment.setAmount(new BigDecimal(amount));
    payment.setCurrency("VND");
    payment.setStatus(status);
    return payment;
  }
}
