package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.config.SepayProperties;
import com.prmteam7.podcasthistory.dto.request.SepayWebhookRequest;
import com.prmteam7.podcasthistory.dto.response.SepayCreateResponse;
import com.prmteam7.podcasthistory.dto.response.SepayPaymentStatusResponse;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.exception.ResourceForbiddenException;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.model.Payment;
import com.prmteam7.podcasthistory.model.Subscription;
import com.prmteam7.podcasthistory.repository.PaymentRepository;
import com.prmteam7.podcasthistory.repository.SubscriptionRepository;
import java.math.BigDecimal;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HexFormat;
import java.util.Locale;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.util.UriComponentsBuilder;

@Service
public class SepayService {
  private static final String API_KEY_SCHEME = "Apikey ";
  private static final String QR_IMAGE_URL = "https://vietqr.app/img";

  private final SepayProperties properties;
  private final PaymentRepository paymentRepository;
  private final SubscriptionRepository subscriptionRepository;
  private final SecureRandom secureRandom = new SecureRandom();

  public SepayService(
      SepayProperties properties,
      PaymentRepository paymentRepository,
      SubscriptionRepository subscriptionRepository) {
    this.properties = properties;
    this.paymentRepository = paymentRepository;
    this.subscriptionRepository = subscriptionRepository;
  }

  @Transactional
  public SepayCreateResponse createPayment(UUID userId, UUID paymentId) {
    if (!properties.isQrConfigured()) {
      throw new IllegalStateException("SePay account number, bank, and payment code prefix must be configured.");
    }

    Payment payment =
        paymentRepository
            .lockById(paymentId)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy payment."));
    if (!payment.getUser().getUserId().equals(userId)) {
      throw new ResourceForbiddenException("Bạn không có quyền tạo QR thanh toán cho payment này.");
    }
    if (!"PENDING".equalsIgnoreCase(payment.getStatus())) {
      throw new ResourceConflictException("Chỉ tạo QR cho payment ở trạng thái PENDING.");
    }
    if (payment.getAmount() == null || payment.getAmount().signum() <= 0) {
      throw new ResourceConflictException("Số tiền thanh toán phải lớn hơn 0.");
    }
    if (!"VND".equalsIgnoreCase(payment.getCurrency())) {
      throw new ResourceConflictException("SePay QR hiện chỉ hỗ trợ thanh toán bằng VND.");
    }
    if (payment.getSubscription() == null) {
      throw new ResourceConflictException("SePay hiện chỉ hỗ trợ checkout membership.");
    }

    if (!"SEPAY".equalsIgnoreCase(payment.getProvider())
        || !StringUtils.hasText(payment.getProviderTransactionId())) {
      payment.setProvider("SEPAY");
      payment.setProviderTransactionId(generatePaymentCode());
      paymentRepository.save(payment);
    }

    String qrUrl =
        UriComponentsBuilder.fromUri(URI.create(QR_IMAGE_URL))
            .queryParam("acc", properties.getAccountNumber())
            .queryParam("bank", properties.getBank())
            .queryParam("amount", payment.getAmount().stripTrailingZeros().toPlainString())
            .queryParam("des", payment.getProviderTransactionId())
            .build()
            .encode()
            .toUriString();

    return new SepayCreateResponse(
        payment.getPaymentId(),
        payment.getProviderTransactionId(),
        payment.getAmount(),
        payment.getCurrency(),
        properties.getAccountNumber(),
        properties.getBank(),
        qrUrl);
  }

  @Transactional(readOnly = true)
  public SepayPaymentStatusResponse getPaymentStatus(UUID userId, UUID paymentId) {
    Payment payment =
        paymentRepository
            .findById(paymentId)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy payment."));
    if (!payment.getUser().getUserId().equals(userId)) {
      throw new ResourceForbiddenException("Bạn không có quyền xem payment này.");
    }
    Subscription subscription = payment.getSubscription();
    return new SepayPaymentStatusResponse(
        payment.getPaymentId(),
        payment.getStatus(),
        subscription == null ? null : subscription.getSubscriptionId(),
        subscription == null ? null : subscription.getStatus());
  }

  public boolean isAuthorized(String authorization) {
    if (!StringUtils.hasText(properties.getWebhookApiKey())
        || !StringUtils.hasText(authorization)
        || authorization.length() <= API_KEY_SCHEME.length()
        || !authorization.regionMatches(true, 0, API_KEY_SCHEME, 0, API_KEY_SCHEME.length())) {
      return false;
    }
    byte[] expected = properties.getWebhookApiKey().getBytes(StandardCharsets.UTF_8);
    byte[] supplied =
        authorization.substring(API_KEY_SCHEME.length()).getBytes(StandardCharsets.UTF_8);
    return MessageDigest.isEqual(expected, supplied);
  }

  @Transactional
  public void processWebhook(SepayWebhookRequest request) {
    if (request == null
        || !"IN".equalsIgnoreCase(request.transferType())
        || !StringUtils.hasText(request.code())
        || request.transferAmount() == null
        || request.transferAmount().signum() <= 0) {
      return;
    }

    Payment matched =
        paymentRepository
            .findByProviderTransactionId(request.code().trim())
            .orElse(null);
    if (matched == null) {
      return;
    }

    Payment payment =
        paymentRepository
            .lockById(matched.getPaymentId())
            .orElse(null);
    if (payment == null
        || !"SEPAY".equalsIgnoreCase(payment.getProvider())
        || !"PENDING".equalsIgnoreCase(payment.getStatus())
        || !"VND".equalsIgnoreCase(payment.getCurrency())
        || payment.getAmount() == null
        || payment.getAmount().compareTo(request.transferAmount()) != 0) {
      return;
    }

    if (payment.getSubscription() != null) {
      Subscription subscription =
          subscriptionRepository
              .lockById(payment.getSubscription().getSubscriptionId())
              .orElse(null);
      if (subscription == null || !"PENDING".equalsIgnoreCase(subscription.getStatus())) {
        return;
      }
      Instant paidAt = Instant.now();
      subscription.setStatus("ACTIVE");
      subscription.setStartAt(paidAt);
      subscription.setEndAt(
          paidAt.plus(subscription.getMembershipPlan().getDurationDays(), ChronoUnit.DAYS));
      subscriptionRepository.save(subscription);
    }

    payment.setStatus("PAID");
    payment.setPaidAt(Instant.now());
    paymentRepository.save(payment);
  }

  private String generatePaymentCode() {
    byte[] randomBytes = new byte[12];
    secureRandom.nextBytes(randomBytes);
    String prefix = properties.getPaymentCodePrefix().trim().toUpperCase(Locale.ROOT);
    return prefix + "-" + HexFormat.of().formatHex(randomBytes).toUpperCase(Locale.ROOT);
  }
}
