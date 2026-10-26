package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.config.SepayProperties;
import com.prmteam7.podcasthistory.dto.request.SepayWebhookRequest;
import com.prmteam7.podcasthistory.dto.response.PaymentStatusItem;
import com.prmteam7.podcasthistory.dto.response.SepayWebhookResponse;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.model.Payment;
import com.prmteam7.podcasthistory.model.Subscription;
import com.prmteam7.podcasthistory.repository.PaymentRepository;
import com.prmteam7.podcasthistory.repository.SubscriptionRepository;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.util.UriComponentsBuilder;

@Service
public class SepayService {

  private static final Logger log = LoggerFactory.getLogger(SepayService.class);
  private static final String CODE_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  private static final String API_KEY_SCHEME = "Apikey ";
  private static final Duration PAYMENT_EXPIRY = Duration.ofMinutes(30);
  private static final Duration WEBHOOK_GRACE = Duration.ofMinutes(5);
  private static final int PAYMENT_CODE_ATTEMPTS = 5;

  private final PaymentRepository paymentRepository;
  private final SubscriptionRepository subscriptionRepository;
  private final SepayProperties properties;
  private final SecureRandom secureRandom = new SecureRandom();

  public SepayService(
      PaymentRepository paymentRepository,
      SubscriptionRepository subscriptionRepository,
      SepayProperties properties) {
    this.paymentRepository = paymentRepository;
    this.subscriptionRepository = subscriptionRepository;
    this.properties = properties;
  }

  public String generatePaymentCode() {
    String prefix = normalizeCode(properties.getCodePrefix());
    int suffixLength = properties.getCodeSuffixLength();
    if (prefix.isEmpty() || !prefix.matches("[A-Z0-9]+")) {
      throw new IllegalStateException("sepay.code-prefix must contain only A-Z and 0-9.");
    }
    if (suffixLength < 1 || suffixLength > 64) {
      throw new IllegalStateException("sepay.code-suffix-length must be between 1 and 64.");
    }

    for (int attempt = 0; attempt < PAYMENT_CODE_ATTEMPTS; attempt++) {
      StringBuilder code = new StringBuilder(prefix);
      for (int index = 0; index < suffixLength; index++) {
        code.append(CODE_ALPHABET.charAt(secureRandom.nextInt(CODE_ALPHABET.length())));
      }
      String candidate = code.toString();
      if (!paymentRepository.existsByPaymentCode(candidate)) {
        return candidate;
      }
    }
    throw new IllegalStateException("Unable to generate a unique SePay payment code.");
  }

  public String createQrImageUrl(BigDecimal amount, String paymentCode) {
    if (properties.getQrBaseUrl() == null || properties.getQrBaseUrl().isBlank()) {
      throw new IllegalStateException("sepay.qr-base-url must be configured.");
    }
    if (properties.getBankAccount() == null || properties.getBankAccount().isBlank()) {
      throw new IllegalStateException("sepay.bank-account must be configured.");
    }
    if (properties.getBankCode() == null || properties.getBankCode().isBlank()) {
      throw new IllegalStateException("sepay.bank-code must be configured.");
    }

    String qrAmount;
    try {
      qrAmount = amount.setScale(0, RoundingMode.UNNECESSARY).toPlainString();
    } catch (ArithmeticException exception) {
      throw new IllegalArgumentException("SePay QR amount must be a whole number.", exception);
    }

    return UriComponentsBuilder.fromUriString(properties.getQrBaseUrl())
        .queryParam("acc", properties.getBankAccount())
        .queryParam("bank", properties.getBankCode())
        .queryParam("amount", qrAmount)
        .queryParam("des", paymentCode)
        .build()
        .encode()
        .toUriString();
  }

  @Transactional
  public PaymentStatusItem getPaymentStatus(UUID userId, UUID paymentId) {
    paymentRepository
        .findByPaymentIdAndUser_UserId(paymentId, userId)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy payment."));

    Payment payment =
        paymentRepository
            .lockById(paymentId)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy payment."));
    Subscription subscription = lockSubscription(payment);
    Instant now = Instant.now();
    Instant expiresAt = expiresAt(payment);

    if ("PENDING".equalsIgnoreCase(payment.getStatus()) && now.isAfter(expiresAt)) {
      expire(payment, subscription);
    }

    return toStatusItem(payment, subscription, expiresAt);
  }

  @Transactional
  public ResponseEntity<SepayWebhookResponse> processWebhook(
      String authorization, SepayWebhookRequest request) {
    if (!hasValidApiKey(authorization)) {
      log.warn("Rejected SePay webhook with invalid API Key.");
      return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
          .body(new SepayWebhookResponse(false));
    }
    Instant receivedAt = Instant.now();

    if (request == null || request.id() == null) {
      log.info("Ignored SePay webhook with missing transaction metadata.");
      return success();
    }

    String transactionId = request.id().toString();
    if (!"in".equalsIgnoreCase(trimToEmpty(request.transferType()))) {
      log.info(
          "Ignored SePay webhook: id={}, code={}, amount={}, result=not_incoming",
          transactionId,
          normalizeCode(request.code()),
          request.transferAmount());
      return success();
    }

    String code = normalizeCode(request.code());
    if (code.isEmpty()) {
      log.info(
          "Ignored SePay webhook: id={}, code=null, amount={}, result=missing_code",
          transactionId,
          request.transferAmount());
      return success();
    }

    Payment payment = paymentRepository.lockByPaymentCode(code).orElse(null);
    if (payment == null) {
      log.info(
          "Ignored SePay webhook: id={}, code={}, amount={}, result=unknown_code",
          transactionId,
          code,
          request.transferAmount());
      return success();
    }

    if ("PAID".equalsIgnoreCase(payment.getStatus())
        || paymentRepository.existsByProviderTransactionId(transactionId)) {
      log.info(
          "Ignored SePay webhook: id={}, code={}, amount={}, result=duplicate",
          transactionId,
          code,
          request.transferAmount());
      return success();
    }

    Subscription subscription = lockSubscription(payment);
    if (!"PENDING".equalsIgnoreCase(payment.getStatus())
        && !"EXPIRED".equalsIgnoreCase(payment.getStatus())) {
      log.info(
          "Ignored SePay webhook: id={}, code={}, amount={}, result=payment_not_pending",
          transactionId,
          code,
          request.transferAmount());
      return success();
    }

    Instant now = receivedAt;
    Instant expiresAt = expiresAt(payment);
    Instant graceDeadline = expiresAt.plus(WEBHOOK_GRACE);
    if (now.isAfter(graceDeadline)) {
      expire(payment, subscription);
      log.info(
          "Ignored late SePay webhook: id={}, code={}, amount={}, result=expired",
          transactionId,
          code,
          request.transferAmount());
      return success();
    }

    if (now.isAfter(expiresAt)) {
      expire(payment, subscription);
    }

    if (request.transferAmount() == null
        || request.transferAmount().compareTo(payment.getAmount()) != 0) {
      log.info(
          "Ignored SePay webhook: id={}, code={}, amount={}, expectedAmount={}, result=amount_mismatch",
          transactionId,
          code,
          request.transferAmount(),
          payment.getAmount());
      return success();
    }

    payment.setProvider("SEPAY");
    payment.setProviderTransactionId(transactionId);
    payment.setStatus("PAID");
    payment.setPaidAt(now);
    subscription.setStatus("ACTIVE");
    subscription.setStartAt(now);
    subscription.setEndAt(
        now.plus(
            subscription.getMembershipPlan().getDurationDays(),
            java.time.temporal.ChronoUnit.DAYS));
    paymentRepository.save(payment);
    subscriptionRepository.save(subscription);

    log.info(
        "Processed SePay webhook: id={}, code={}, amount={}, result=paid",
        transactionId,
        code,
        request.transferAmount());
    return success();
  }

  private boolean hasValidApiKey(String authorization) {
    String expected = properties.getWebhookApiKey();
    if (expected == null
        || expected.isBlank()
        || authorization == null
        || !authorization.startsWith(API_KEY_SCHEME)) {
      return false;
    }
    byte[] expectedBytes = expected.getBytes(StandardCharsets.UTF_8);
    byte[] suppliedBytes =
        authorization.substring(API_KEY_SCHEME.length()).getBytes(StandardCharsets.UTF_8);
    return MessageDigest.isEqual(expectedBytes, suppliedBytes);
  }

  private Subscription lockSubscription(Payment payment) {
    if (payment.getSubscription() == null) {
      throw new IllegalStateException("SePay membership payment has no linked subscription.");
    }
    UUID subscriptionId = payment.getSubscription().getSubscriptionId();
    return subscriptionRepository
        .lockById(subscriptionId)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy subscription."));
  }

  private Instant expiresAt(Payment payment) {
    if (payment.getCreatedAt() == null) {
      throw new IllegalStateException("Payment creation time is required for expiry checks.");
    }
    return payment.getCreatedAt().plus(PAYMENT_EXPIRY);
  }

  private void expire(Payment payment, Subscription subscription) {
    payment.setStatus("EXPIRED");
    subscription.setStatus("EXPIRED");
    paymentRepository.save(payment);
    subscriptionRepository.save(subscription);
  }

  private PaymentStatusItem toStatusItem(
      Payment payment, Subscription subscription, Instant expiresAt) {
    return new PaymentStatusItem(
        payment.getPaymentId(),
        subscription.getSubscriptionId(),
        payment.getPaymentCode(),
        payment.getAmount(),
        payment.getCurrency(),
        payment.getStatus(),
        subscription.getStatus(),
        payment.getPaidAt(),
        expiresAt);
  }

  private String normalizeCode(String code) {
    return trimToEmpty(code).toUpperCase(Locale.ROOT);
  }

  private String trimToEmpty(String value) {
    return value == null ? "" : value.trim();
  }

  private ResponseEntity<SepayWebhookResponse> success() {
    return ResponseEntity.ok(new SepayWebhookResponse(true));
  }
}
