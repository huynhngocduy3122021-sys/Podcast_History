package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.prmteam7.podcasthistory.config.SepayProperties;
import com.prmteam7.podcasthistory.dto.request.SepayWebhookRequest;
import com.prmteam7.podcasthistory.dto.response.SepayWebhookResponse;
import com.prmteam7.podcasthistory.model.MembershipPlan;
import com.prmteam7.podcasthistory.model.Payment;
import com.prmteam7.podcasthistory.model.Subscription;
import com.prmteam7.podcasthistory.repository.PaymentRepository;
import com.prmteam7.podcasthistory.repository.SubscriptionRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

@ExtendWith(MockitoExtension.class)
class SepayServiceTest {

  private static final String API_KEY = "test-sepay-api-key";
  private static final String PAYMENT_CODE = "DH123456789ABCDE";

  @Mock private PaymentRepository paymentRepository;
  @Mock private SubscriptionRepository subscriptionRepository;

  private SepayService sepayService;

  @BeforeEach
  void setUp() {
    SepayProperties properties = new SepayProperties();
    properties.setWebhookApiKey(API_KEY);
    sepayService = new SepayService(paymentRepository, subscriptionRepository, properties);
  }

  @Test
  void rejectsInvalidApiKeyWithoutLookingUpPayment() {
    ResponseEntity<SepayWebhookResponse> response =
        sepayService.processWebhook("Apikey wrong-key", webhook(PAYMENT_CODE, "50000"));

    assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
    assertFalse(response.getBody().success());
    verifyNoInteractions(paymentRepository, subscriptionRepository);
  }

  @Test
  void acknowledgesNullCodeWithoutLookingUpPayment() {
    ResponseEntity<SepayWebhookResponse> response =
        sepayService.processWebhook(API_KEY_HEADER, webhook(null, "50000"));

    assertEquals(HttpStatus.OK, response.getStatusCode());
    assertTrue(response.getBody().success());
    verifyNoInteractions(paymentRepository, subscriptionRepository);
  }

  @Test
  void acknowledgesUnknownCodeWithoutUpdatingPayment() {
    when(paymentRepository.lockByPaymentCode("DHUNKNOWN")).thenReturn(Optional.empty());

    ResponseEntity<SepayWebhookResponse> response =
        sepayService.processWebhook(API_KEY_HEADER, webhook("  dhunknown ", "50000"));

    assertEquals(HttpStatus.OK, response.getStatusCode());
    assertTrue(response.getBody().success());
  }

  @Test
  void leavesPaymentPendingWhenAmountDoesNotMatch() {
    Payment payment = pendingPayment(Instant.now().minusSeconds(60));
    when(paymentRepository.lockByPaymentCode(PAYMENT_CODE)).thenReturn(Optional.of(payment));
    when(paymentRepository.existsByProviderTransactionId("42")).thenReturn(false);
    when(subscriptionRepository.lockById(payment.getSubscription().getSubscriptionId()))
        .thenReturn(Optional.of(payment.getSubscription()));

    ResponseEntity<SepayWebhookResponse> response =
        sepayService.processWebhook(API_KEY_HEADER, webhook(PAYMENT_CODE, "49999"));

    assertEquals(HttpStatus.OK, response.getStatusCode());
    assertTrue(response.getBody().success());
    assertEquals("PENDING", payment.getStatus());
    assertEquals("PENDING", payment.getSubscription().getStatus());
    assertNull(payment.getProviderTransactionId());
  }

  @Test
  void acknowledgesDuplicateTransactionWithoutApplyingItAgain() {
    Payment payment = pendingPayment(Instant.now().minusSeconds(60));
    when(paymentRepository.lockByPaymentCode(PAYMENT_CODE)).thenReturn(Optional.of(payment));
    when(paymentRepository.existsByProviderTransactionId("42")).thenReturn(true);

    ResponseEntity<SepayWebhookResponse> response =
        sepayService.processWebhook(API_KEY_HEADER, webhook(PAYMENT_CODE, "50000"));

    assertEquals(HttpStatus.OK, response.getStatusCode());
    assertTrue(response.getBody().success());
    assertEquals("PENDING", payment.getStatus());
    verify(subscriptionRepository, org.mockito.Mockito.never())
        .lockById(payment.getSubscription().getSubscriptionId());
  }

  @Test
  void activatesSubscriptionWhenIncomingAmountMatches() {
    Payment payment = pendingPayment(Instant.now().minusSeconds(60));
    when(paymentRepository.lockByPaymentCode(PAYMENT_CODE)).thenReturn(Optional.of(payment));
    when(paymentRepository.existsByProviderTransactionId("42")).thenReturn(false);
    when(subscriptionRepository.lockById(payment.getSubscription().getSubscriptionId()))
        .thenReturn(Optional.of(payment.getSubscription()));
    Instant beforeWebhook = Instant.now();

    ResponseEntity<SepayWebhookResponse> response =
        sepayService.processWebhook(
            API_KEY_HEADER, webhook("  " + PAYMENT_CODE.toLowerCase() + "  ", "50000.00"));

    Instant afterWebhook = Instant.now();
    assertEquals(HttpStatus.OK, response.getStatusCode());
    assertTrue(response.getBody().success());
    assertEquals("PAID", payment.getStatus());
    assertEquals("42", payment.getProviderTransactionId());
    assertEquals("SEPAY", payment.getProvider());
    assertNotNull(payment.getPaidAt());
    assertFalse(payment.getPaidAt().isBefore(beforeWebhook));
    assertFalse(payment.getPaidAt().isAfter(afterWebhook));
    assertEquals("ACTIVE", payment.getSubscription().getStatus());
    assertEquals(payment.getPaidAt(), payment.getSubscription().getStartAt());
    assertEquals(
        payment.getPaidAt().plusSeconds(30L * 24 * 60 * 60),
        payment.getSubscription().getEndAt());
    verify(paymentRepository).save(payment);
    verify(subscriptionRepository).save(payment.getSubscription());
  }

  @Test
  void expiresPaymentAfterGraceWindowWithoutActivatingSubscription() {
    Payment payment = pendingPayment(Instant.now().minusSeconds(36 * 60));
    when(paymentRepository.lockByPaymentCode(PAYMENT_CODE)).thenReturn(Optional.of(payment));
    when(paymentRepository.existsByProviderTransactionId("42")).thenReturn(false);
    when(subscriptionRepository.lockById(payment.getSubscription().getSubscriptionId()))
        .thenReturn(Optional.of(payment.getSubscription()));

    ResponseEntity<SepayWebhookResponse> response =
        sepayService.processWebhook(API_KEY_HEADER, webhook(PAYMENT_CODE, "50000"));

    assertEquals(HttpStatus.OK, response.getStatusCode());
    assertTrue(response.getBody().success());
    assertEquals("EXPIRED", payment.getStatus());
    assertEquals("EXPIRED", payment.getSubscription().getStatus());
    assertNull(payment.getProviderTransactionId());
  }

  @Test
  void acceptsMatchingPaymentDuringWebhookGraceWindow() {
    Payment payment = pendingPayment(Instant.now().minusSeconds(32 * 60));
    payment.setStatus("EXPIRED");
    payment.getSubscription().setStatus("EXPIRED");
    when(paymentRepository.lockByPaymentCode(PAYMENT_CODE)).thenReturn(Optional.of(payment));
    when(paymentRepository.existsByProviderTransactionId("42")).thenReturn(false);
    when(subscriptionRepository.lockById(payment.getSubscription().getSubscriptionId()))
        .thenReturn(Optional.of(payment.getSubscription()));

    ResponseEntity<SepayWebhookResponse> response =
        sepayService.processWebhook(API_KEY_HEADER, webhook(PAYMENT_CODE, "50000"));

    assertEquals(HttpStatus.OK, response.getStatusCode());
    assertTrue(response.getBody().success());
    assertEquals("PAID", payment.getStatus());
    assertEquals("ACTIVE", payment.getSubscription().getStatus());
  }

  private static final String API_KEY_HEADER = "Apikey " + API_KEY;

  private SepayWebhookRequest webhook(String code, String amount) {
    return new SepayWebhookRequest(42L, "in", new BigDecimal(amount), code, "payment content");
  }

  private Payment pendingPayment(Instant createdAt) {
    MembershipPlan plan = new MembershipPlan();
    plan.setDurationDays(30);

    Subscription subscription = new Subscription();
    subscription.setSubscriptionId(UUID.randomUUID());
    subscription.setMembershipPlan(plan);
    subscription.setStatus("PENDING");

    Payment payment = new Payment();
    payment.setPaymentId(UUID.randomUUID());
    payment.setPaymentCode(PAYMENT_CODE);
    payment.setAmount(new BigDecimal("50000.00"));
    payment.setCurrency("VND");
    payment.setStatus("PENDING");
    payment.setCreatedAt(createdAt);
    payment.setSubscription(subscription);
    return payment;
  }
}
