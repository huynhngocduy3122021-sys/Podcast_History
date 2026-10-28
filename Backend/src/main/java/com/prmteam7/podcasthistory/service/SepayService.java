package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.config.SepayProperties;
import com.prmteam7.podcasthistory.dto.request.SepayWebhookRequest;
import com.prmteam7.podcasthistory.dto.response.PaymentStatusItem;
import com.prmteam7.podcasthistory.dto.response.CheckoutPaymentView;
import com.prmteam7.podcasthistory.dto.response.CheckoutHistoryItem;
import com.prmteam7.podcasthistory.dto.response.SepayWebhookResponse;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.model.Payment;
import com.prmteam7.podcasthistory.model.Subscription;
import com.prmteam7.podcasthistory.model.CheckoutPayment;
import com.prmteam7.podcasthistory.model.CreatorSystemSubscription;
import com.prmteam7.podcasthistory.model.UserWallet;
import com.prmteam7.podcasthistory.model.WalletTransaction;
import com.prmteam7.podcasthistory.model.PaymentMethod;
import com.prmteam7.podcasthistory.repository.PaymentRepository;
import com.prmteam7.podcasthistory.repository.SubscriptionRepository;
import com.prmteam7.podcasthistory.repository.CheckoutPaymentRepository;
import com.prmteam7.podcasthistory.repository.CreatorSystemSubscriptionRepository;
import com.prmteam7.podcasthistory.repository.UserWalletRepository;
import com.prmteam7.podcasthistory.repository.WalletTransactionRepository;
import com.prmteam7.podcasthistory.repository.PaymentMethodRepository;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.scheduling.annotation.Scheduled;
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
  private final CheckoutPaymentRepository checkoutRepository;
  private final CreatorSystemSubscriptionRepository creatorSubscriptions;
  private final UserWalletRepository wallets;
  private final WalletTransactionRepository walletTransactions;
  private final PaymentMethodRepository paymentMethods;
  private final SepayProperties properties;
  private final RealtimeEventPublisher realtime;
  private final SecureRandom secureRandom = new SecureRandom();

  public SepayService(
      PaymentRepository paymentRepository,
      SubscriptionRepository subscriptionRepository,
      CheckoutPaymentRepository checkoutRepository,
      CreatorSystemSubscriptionRepository creatorSubscriptions,
      UserWalletRepository wallets,
      WalletTransactionRepository walletTransactions,
      PaymentMethodRepository paymentMethods,
      SepayProperties properties,
      RealtimeEventPublisher realtime) {
    this.paymentRepository = paymentRepository;
    this.subscriptionRepository = subscriptionRepository;
    this.checkoutRepository = checkoutRepository;
    this.creatorSubscriptions = creatorSubscriptions;
    this.wallets = wallets;
    this.walletTransactions = walletTransactions;
    this.paymentMethods = paymentMethods;
    this.properties = properties;
    this.realtime = realtime;
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
      if (!paymentRepository.existsByPaymentCode(candidate)
          && !checkoutRepository.existsByPaymentCode(candidate)) {
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
  public CheckoutPaymentView getCheckoutStatus(UUID userId, UUID checkoutId) {
    checkoutRepository.findByCheckoutIdAndUser_UserId(checkoutId, userId)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy checkout."));
    CheckoutPayment checkout = checkoutRepository.lockById(checkoutId).orElseThrow();
    Instant expiresAt = checkout.getCreatedAt().plus(PAYMENT_EXPIRY);
    if ("PENDING".equals(checkout.getStatus()) && Instant.now().isAfter(expiresAt))
      expireCheckout(checkout);
    return new CheckoutPaymentView(checkout.getCheckoutId(),
        checkout.getCreatorSubscription() == null ? null : checkout.getCreatorSubscription().getSubscriptionId(),
        checkout.getPurpose(), checkout.getPaymentCode(), createQrImageUrl(checkout.getAmount(), checkout.getPaymentCode()), checkout.getAmount(),
        checkout.getCurrency(), checkout.getStatus(), checkout.getPaidAt(), expiresAt);
  }

  @Scheduled(fixedDelay = 60_000)
  @Transactional
  public void failExpiredWalletTopUps() {
    int count = checkoutRepository.failExpiredWalletTopUps(Instant.now().minus(PAYMENT_EXPIRY));
    if (count > 0) log.info("Marked {} expired wallet top-ups as FAILED.", count);
  }

  @Transactional(readOnly = true)
  public Page<CheckoutHistoryItem> getCheckoutHistory(
      UUID userId, String status, int page, int size) {
    String normalizedStatus = status == null ? null : status.trim();
    if (normalizedStatus != null && normalizedStatus.isBlank()) normalizedStatus = null;
    Pageable pageable = PageRequest.of(
        Math.max(0, page),
        Math.min(100, Math.max(1, size)),
        Sort.by(Sort.Direction.DESC, "createdAt"));
    return checkoutRepository.findForUser(userId, normalizedStatus, pageable).map(checkout ->
        new CheckoutHistoryItem(
            checkout.getCheckoutId(),
            checkout.getPurpose(),
            checkout.getPaymentCode(),
            checkout.getAmount(),
            checkout.getCurrency(),
            checkout.getStatus(),
            checkout.getCreatedAt(),
            checkout.getPaidAt(),
            checkout.getCreatedAt().plus(PAYMENT_EXPIRY),
            checkout.getProviderTransactionId()));
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

    String code = resolvePaymentCode(request);
    if (code.isEmpty()) {
      log.info(
          "Ignored SePay webhook: id={}, code=null, amount={}, result=missing_code",
          transactionId,
          request.transferAmount());
      return success();
    }

    Payment payment = paymentRepository.lockByPaymentCode(code).orElse(null);
    if (payment == null) {
      return processCheckoutWebhook(code, transactionId, request, receivedAt);
    }

    if ("PAID".equalsIgnoreCase(payment.getStatus())
        || paymentRepository.existsByProviderTransactionId(transactionId)
        || checkoutRepository.existsByProviderTransactionId(transactionId)) {
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
    PaymentMethod method = new PaymentMethod();
    method.setPayment(payment);
    method.setMethodCode("SEPAY");
    method.setDisplayName("SePay transfer");
    method.setIsActive(true);
    paymentMethods.save(method);
    if (payment.getUser() != null) {
      realtime.publishUser(
          payment.getUser().getUserId(),
          "PAYMENT_UPDATED",
          java.util.Map.of(
              "paymentId", payment.getPaymentId(),
              "subscriptionId", subscription.getSubscriptionId(),
              "status", payment.getStatus(),
              "subscriptionStatus", subscription.getStatus(),
              "amount", payment.getAmount(),
              "currency", payment.getCurrency()));
    }

    log.info(
        "Processed SePay webhook: id={}, code={}, amount={}, result=paid",
        transactionId,
        code,
        request.transferAmount());
    return success();
  }

  private ResponseEntity<SepayWebhookResponse> processCheckoutWebhook(
      String code, String transactionId, SepayWebhookRequest request, Instant receivedAt) {
    CheckoutPayment checkout = checkoutRepository.lockByPaymentCode(code).orElse(null);
    if (checkout == null) {
      log.info("Ignored SePay webhook: id={}, code={}, result=unknown_code", transactionId, code);
      return success();
    }
    if (!"PENDING".equals(checkout.getStatus()) && !"EXPIRED".equals(checkout.getStatus())
        && !"FAILED".equals(checkout.getStatus()))
      return success();
    if (paymentRepository.existsByProviderTransactionId(transactionId)
        || checkoutRepository.existsByProviderTransactionId(transactionId)) {
      log.info("Ignored SePay checkout webhook: id={}, code={}, result=duplicate", transactionId, code);
      return success();
    }
    if (receivedAt.isAfter(checkout.getCreatedAt().plus(PAYMENT_EXPIRY).plus(WEBHOOK_GRACE))) {
      expireCheckout(checkout);
      log.info("Ignored SePay checkout webhook: id={}, code={}, result=expired", transactionId, code);
      return success();
    }
    if (request.transferAmount() == null
        || request.transferAmount().compareTo(checkout.getAmount()) != 0) {
      log.info("Ignored SePay checkout webhook: id={}, code={}, amount={}, expectedAmount={}, result=amount_mismatch",
          transactionId, code, request.transferAmount(), checkout.getAmount());
      return success();
    }

    if ("WALLET_TOPUP".equals(checkout.getPurpose())) {
      UserWallet wallet = wallets.findByUserIdForUpdate(checkout.getUser().getUserId())
          .orElseThrow(() -> new IllegalStateException("Không tìm thấy ví nạp tiền."));
      if (!"ACTIVE".equalsIgnoreCase(wallet.getStatus()) || !"VND".equalsIgnoreCase(wallet.getCurrency().trim()))
        throw new IllegalStateException("Ví nạp tiền không hợp lệ.");
      wallet.setBalance(wallet.getBalance().add(checkout.getAmount()));
      wallets.save(wallet);
      WalletTransaction transaction = new WalletTransaction();
      transaction.setUserWallet(wallet);
      transaction.setTransactionType("WALLET_TOPUP");
      transaction.setDirection("CREDIT");
      transaction.setAmount(checkout.getAmount());
      transaction.setCurrency("VND");
      transaction.setReferenceCode("TOPUP:" + checkout.getCheckoutId());
      transaction.setStatus("COMPLETED");
      transaction.setBalanceAfter(wallet.getBalance());
      transaction.setHeldBalanceAfter(wallet.getHeldBalance());
      walletTransactions.save(transaction);
    } else if ("CREATOR_PLAN".equals(checkout.getPurpose())) {
      CreatorSystemSubscription subscription = creatorSubscriptions.findById(
          checkout.getCreatorSubscription().getSubscriptionId()).orElseThrow();
      if (!"PENDING".equals(subscription.getPaymentStatus())) return success();
      subscription.setPaymentStatus("SUCCEEDED");
      subscription.setStartAt(receivedAt);
      subscription.setEndAt(receivedAt.plus(subscription.getPlan().getDurationDays(),
          java.time.temporal.ChronoUnit.DAYS));
      creatorSubscriptions.save(subscription);
    } else {
      throw new IllegalStateException("Loại checkout không hợp lệ.");
    }
    checkout.setStatus("PAID");
    checkout.setPaidAt(receivedAt);
    checkout.setProviderTransactionId(transactionId);
    checkoutRepository.save(checkout);
    if (checkout.getUser() != null) {
      realtime.publishUser(
          checkout.getUser().getUserId(),
          "PAYMENT_UPDATED",
          java.util.Map.of(
              "checkoutId", checkout.getCheckoutId(),
              "purpose", checkout.getPurpose(),
              "status", checkout.getStatus(),
              "amount", checkout.getAmount(),
              "currency", checkout.getCurrency()));
    }
    log.info("Processed SePay checkout webhook: id={}, code={}, purpose={}, result=paid",
        transactionId, code, checkout.getPurpose());
    return success();
  }

  private void expireCheckout(CheckoutPayment checkout) {
    checkout.setStatus("WALLET_TOPUP".equals(checkout.getPurpose()) ? "FAILED" : "EXPIRED");
    checkoutRepository.save(checkout);
    if (checkout.getCreatorSubscription() != null) {
      CreatorSystemSubscription subscription = creatorSubscriptions.findById(
          checkout.getCreatorSubscription().getSubscriptionId()).orElseThrow();
      if ("PENDING".equals(subscription.getPaymentStatus())) {
        subscription.setPaymentStatus("EXPIRED");
        creatorSubscriptions.save(subscription);
      }
    }
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

  private String resolvePaymentCode(SepayWebhookRequest request) {
    String code = normalizeCode(request.code());
    if (!code.isEmpty()) return code;
    String prefix = normalizeCode(properties.getCodePrefix());
    int suffixLength = properties.getCodeSuffixLength();
    if (prefix.isEmpty() || suffixLength < 1 || suffixLength > 64) return "";
    String content = normalizeCode(request.content());
    Pattern pattern = Pattern.compile("(?<![A-Z0-9])" + Pattern.quote(prefix)
        + "[A-Z0-9]{" + suffixLength + "}(?![A-Z0-9])");
    Matcher matcher = pattern.matcher(content);
    if (!matcher.find()) return "";
    String matchedCode = matcher.group();
    return matcher.find() ? "" : matchedCode;
  }

  private String trimToEmpty(String value) {
    return value == null ? "" : value.trim();
  }

  private ResponseEntity<SepayWebhookResponse> success() {
    return ResponseEntity.ok(new SepayWebhookResponse(true));
  }
}
