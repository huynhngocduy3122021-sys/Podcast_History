package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.request.AdminRequests.*;
import com.prmteam7.podcasthistory.config.PackageFeatures;
import com.prmteam7.podcasthistory.dto.response.AdminResponses.*;
import com.prmteam7.podcasthistory.enums.ManualPaymentResult;
import com.prmteam7.podcasthistory.exception.*;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Locale;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class AdminFinanceService {
  private final AdminSupportService support;
  private final WithdrawalRequestRepository withdrawals;
  private final WithdrawalReviewRepository reviews;
  private final UserWalletRepository wallets;
  private final WalletTransactionRepository transactions;
  private final PaymentRepository payments;
  private final PaymentMethodRepository paymentMethods;
  private final SubscriptionRepository subscriptions;
  private final AppUserRepository users;
  private final ContractRepository contracts;
  private final PackageFeatures packageFeatures;
  private final AudienceNotificationService audienceNotifications;

  public AdminFinanceService(
      AdminSupportService support,
      WithdrawalRequestRepository withdrawals,
      WithdrawalReviewRepository reviews,
      UserWalletRepository wallets,
      WalletTransactionRepository transactions,
      PaymentRepository payments,
      PaymentMethodRepository paymentMethods,
      SubscriptionRepository subscriptions,
      AppUserRepository users,
      ContractRepository contracts,
      PackageFeatures packageFeatures,
      AudienceNotificationService audienceNotifications) {
    this.support = support;
    this.withdrawals = withdrawals;
    this.reviews = reviews;
    this.wallets = wallets;
    this.transactions = transactions;
    this.payments = payments;
    this.paymentMethods = paymentMethods;
    this.subscriptions = subscriptions;
    this.users = users;
    this.contracts = contracts;
    this.packageFeatures = packageFeatures;
    this.audienceNotifications = audienceNotifications;
  }

  public Page<WithdrawalItem> withdrawals(UUID actor, String status, int page, int size) {
    support.actor(actor, true);
    return withdrawals
        .findAll(AdminSupportService.status(status), AdminSupportService.page(page, size))
        .map(this::withdrawalItem);
  }

  public WithdrawalItem withdrawal(UUID actor, UUID id) {
    support.actor(actor, true);
    return withdrawalItem(requireWithdrawal(id));
  }

  public Page<WithdrawalReviewItem> withdrawalReviews(UUID actor, UUID id, int page, int size) {
    support.actor(actor, true);
    requireWithdrawal(id);
    return reviews
        .findAllByWithdrawalRequest_WithdrawalRequestIdOrderByReviewedAtDesc(
            id, AdminSupportService.page(page, size))
        .map(
            r ->
                new WithdrawalReviewItem(
                    r.getWithdrawalReviewId(),
                    r.getReviewerUser().getUserId(),
                    r.getDecision(),
                    r.getNote(),
                    r.getReviewedAt()));
  }

  @Transactional
  public WithdrawalItem approve(UUID actor, UUID id, ApproveWithdrawal body) {
    AppUser admin = support.actor(actor, true);
    WithdrawalRequest w = lockWithdrawal(id);
    AdminSupportService.state(w.getStatus(), "PENDING");
    if (!Boolean.TRUE.equals(body.payoutAccountVerified()))
      throw new InvalidFlowRequestException("Phải xác minh tài khoản nhận tiền trước khi duyệt.");
    if (w.isFundsReserved())
      throw new ResourceConflictException(
          "Yêu cầu đã giữ tiền; cần kiểm tra dữ liệu trước khi duyệt lại.");
    UserWallet wallet = lockWallet(w.getUserWallet().getUserWalletId());
    if (!wallet.getUser().getUserId().equals(w.getProducerProfile().getUser().getUserId())
        || !wallet.getCurrency().trim().equals(w.getCurrency().trim())
        || !"ACTIVE".equalsIgnoreCase(wallet.getStatus())
        || !Boolean.TRUE.equals(w.getProducerProfile().getUser().getIsActive())
        || w.getPayoutMethod() == null
        || w.getPayoutMethod().isBlank()
        || w.getPayoutAccountMasked() == null
        || w.getPayoutAccountMasked().isBlank())
      throw new ResourceConflictException("Ví, người nhận hoặc tài khoản thanh toán không hợp lệ.");
    if (w.getAmount() == null
        || w.getAmount().signum() <= 0
        || wallet.getBalance().compareTo(w.getAmount()) < 0)
      throw new ResourceConflictException("Số dư khả dụng không đủ hoặc số tiền không hợp lệ.");
    wallet.setBalance(wallet.getBalance().subtract(w.getAmount()));
    WalletTransaction tx = new WalletTransaction();
    tx.setUserWallet(wallet);
    tx.setWithdrawalRequest(w);
    tx.setTransactionType("WITHDRAWAL");
    tx.setDirection("OUT");
    tx.setAmount(w.getAmount());
    tx.setCurrency(w.getCurrency());
    tx.setStatus("PENDING");
    tx.setBalanceAfter(wallet.getBalance());
    tx.setReferenceCode("WITHDRAWAL:" + id);
    transactions.save(tx);
    w.setFundsReserved(true);
    w.setStatus("PROCESSING");
    w.setNote(body.note());
    record(admin, w, "APPROVED", body.note());
    return withdrawalItem(withdrawals.save(w));
  }

  @Transactional
  public WithdrawalItem reject(UUID actor, UUID id, String note) {
    AppUser admin = support.actor(actor, true);
    WithdrawalRequest w = lockWithdrawal(id);
    AdminSupportService.state(w.getStatus(), "PENDING");
    if (w.isFundsReserved())
      throw new ResourceConflictException(
          "Yêu cầu đã giữ tiền; dùng fail để hoàn trả đúng nghiệp vụ.");
    w.setStatus("REJECTED");
    w.setProcessedAt(Instant.now());
    w.setNote(note);
    record(admin, w, "REJECTED", note);
    return withdrawalItem(withdrawals.save(w));
  }

  @Transactional
  public WithdrawalItem complete(UUID actor, UUID id, CompleteWithdrawal body) {
    AppUser admin = support.actor(actor, true);
    WithdrawalRequest w = lockWithdrawal(id);
    AdminSupportService.state(w.getStatus(), "PROCESSING");
    requireReserved(w);
    String reference = body.payoutReference().trim();
    if (withdrawals.existsByPayoutReference(reference))
      throw new ResourceConflictException("Mã chuyển khoản đã được ghi nhận.");
    UserWallet wallet = lockWallet(w.getUserWallet().getUserWalletId());
    WalletTransaction tx = hold(id);
    tx.setStatus("COMPLETED");
    tx.setReferenceCode(reference);
    tx.setBalanceAfter(wallet.getBalance());
    w.setFundsReserved(false);
    w.setPayoutReference(reference);
    w.setStatus("COMPLETED");
    w.setProcessedAt(Instant.now());
    w.setNote(body.note());
    record(admin, w, "COMPLETED", body.note());
    return withdrawalItem(withdrawals.save(w));
  }

  @Transactional
  public WithdrawalItem fail(UUID actor, UUID id, String note) {
    AppUser admin = support.actor(actor, true);
    WithdrawalRequest w = lockWithdrawal(id);
    AdminSupportService.state(w.getStatus(), "PROCESSING");
    requireReserved(w);
    UserWallet wallet = lockWallet(w.getUserWallet().getUserWalletId());
    WalletTransaction tx = hold(id);
    wallet.setBalance(wallet.getBalance().add(w.getAmount()));
    tx.setStatus("FAILED");
    tx.setBalanceAfter(wallet.getBalance());
    w.setFundsReserved(false);
    w.setStatus("FAILED");
    w.setProcessedAt(Instant.now());
    w.setNote(note);
    record(admin, w, "FAILED_RELEASED", note);
    return withdrawalItem(withdrawals.save(w));
  }

  public Page<WalletItem> wallets(UUID actor, int page, int size) {
    support.actor(actor, true);
    return wallets
        .findAll(AdminSupportService.page(page, size))
        .map(
            w ->
                new WalletItem(
                    w.getUserWalletId(),
                    w.getUser().getUserId(),
                    w.getBalance(),
                    w.getCurrency(),
                    w.getStatus()));
  }

  public Page<TransactionItem> transactions(
      UUID actor, UUID walletId, String status, int page, int size) {
    support.actor(actor, true);
    return transactions
        .findAll(
            AdminSupportService.<WalletTransaction>status(status)
                .and(
                    (r, q, c) ->
                        walletId == null
                            ? c.conjunction()
                            : c.equal(r.get("userWallet").get("userWalletId"), walletId)),
            AdminSupportService.page(page, size))
        .map(
            t ->
                new TransactionItem(
                    t.getWalletTransactionId(),
                    t.getUserWallet() == null ? null : t.getUserWallet().getUserWalletId(),
                    t.getWithdrawalRequest() == null
                        ? null
                        : t.getWithdrawalRequest().getWithdrawalRequestId(),
                    t.getPayment() == null ? null : t.getPayment().getPaymentId(),
                    t.getTransactionType(),
                    t.getDirection(),
                    t.getAmount(),
                    t.getCurrency(),
                    t.getStatus(),
                    t.getReferenceCode(),
                    t.getBalanceAfter(),
                    t.getCreatedAt()));
  }

  public Page<PaymentItem> payments(UUID actor, String status, int page, int size) {
    support.actor(actor, true);
    return payments
        .findAll(AdminSupportService.status(status), AdminSupportService.page(page, size))
        .map(this::paymentItem);
  }

  public PaymentItem payment(UUID actor, UUID id) {
    support.actor(actor, true);
    return paymentItem(
        payments
            .findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy payment.")));
  }

  @Transactional
  public PaymentItem reconcile(UUID actor, UUID id, ReconcilePayment body) {
    AppUser admin = support.actor(actor, true);
    Payment p = lockPayment(id);
    AdminSupportService.state(p.getStatus(), "PENDING");
    if (p.getAmount() == null || p.getAmount().signum() <= 0)
      throw new ResourceConflictException("Payment phải có số tiền lớn hơn 0 để đối soát.");
    // Serialize channel membership activation for a user, including concurrent checkouts.
    users
        .lockById(p.getUser().getUserId())
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người thanh toán."));
    Instant now = Instant.now();
    if (body.result() == ManualPaymentResult.PAID) {
      if (body.providerTransactionId() == null || body.providerTransactionId().isBlank())
        throw new InvalidFlowRequestException("Cần mã giao dịch chuyển khoản đã đối soát.");
      String reference = body.providerTransactionId().trim();
      if (payments.existsByProviderTransactionId(reference))
        throw new ResourceConflictException("Mã giao dịch đã được sử dụng.");
      if (p.getSubscription() != null) {
        packageFeatures.requireMemberships();
        Subscription s =
            subscriptions
                .lockById(p.getSubscription().getSubscriptionId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy subscription."));
        AdminSupportService.state(s.getStatus(), "PENDING");
        var plan = s.getMembershipPlan();
        if (!p.getCurrency().trim().equals(plan.getCurrency().trim())
            || p.getAmount().compareTo(plan.getPrice()) != 0)
          throw new ResourceConflictException(
              "Số tiền/tiền tệ của checkout không khớp gói; cần đối soát riêng.");
        if (!Boolean.TRUE.equals(p.getUser().getIsActive())
            || !"ACTIVE".equalsIgnoreCase(plan.getStatus())
            || !"APPROVED".equalsIgnoreCase(plan.getProducerProfile().getVerificationStatus())
            || !Boolean.TRUE.equals(plan.getProducerProfile().getUser().getIsActive()))
          throw new ResourceConflictException("Người dùng hoặc gói/kênh không còn hoạt động.");
        if (subscriptions
            .existsByUser_UserIdAndMembershipPlan_ProducerProfile_ProducerProfileIdAndStatusIgnoreCaseAndStartAtBeforeAndEndAtAfter(
                p.getUser().getUserId(),
                plan.getProducerProfile().getProducerProfileId(),
                "ACTIVE",
                now,
                now))
          throw new ResourceConflictException(
              "Đã có membership ACTIVE cùng kênh; cần xử lý checkout trùng trước.");
        s.setStartAt(now);
        s.setEndAt(now.plus(plan.getDurationDays(), ChronoUnit.DAYS));
        s.setStatus("ACTIVE");
        audienceNotifications.newMembership(plan.getProducerProfile().getUser(), p.getUser(),
            plan.getProducerProfile().getProducerProfileId(), s.getSubscriptionId(),
            plan.getMembershipPlanId());
      } else if (p.getContractStage() != null) {
        var stage = p.getContractStage();
        AdminSupportService.state(stage.getStatus(), "APPROVED", "COMPLETED");
        var contract =
            contracts
                .lockById(stage.getContract().getContractId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy hợp đồng."));
        AdminSupportService.state(contract.getStatus(), "ACTIVE", "IN_PROGRESS", "COMPLETED");
      }
      p.setStatus("PAID");
      p.setPaidAt(now);
      p.setProviderTransactionId(reference);
      p.setProvider("MANUAL_TRANSFER");
      ensurePaymentMethod(p);
    } else {
      p.setStatus("FAILED");
      if (p.getSubscription() != null) {
        var s = subscriptions.lockById(p.getSubscription().getSubscriptionId()).orElseThrow();
        AdminSupportService.state(s.getStatus(), "PENDING");
        s.setStatus("CANCELLED");
      }
    }
    support.audit(admin, "RECONCILE_" + body.result(), "PAYMENT", id, body.note());
    support.notify(
        p.getUser(),
        "PAYMENT_RESULT",
        "Kết quả đối soát thanh toán",
        body.result() + ": " + body.note());
    return paymentItem(payments.save(p));
  }

  private void ensurePaymentMethod(Payment payment) {
    String methodCode = payment.getPaymentMethod();
    if (methodCode == null || methodCode.isBlank()) {
      methodCode = "MANUAL_TRANSFER";
    } else {
      methodCode = methodCode.trim().toUpperCase(Locale.ROOT);
    }
    payment.setPaymentMethod(methodCode);

    PaymentMethod method = paymentMethods
        .findFirstByPayment_PaymentIdAndMethodCodeIgnoreCase(payment.getPaymentId(), methodCode)
        .orElseGet(PaymentMethod::new);
    method.setPayment(payment);
    method.setMethodCode(methodCode);
    method.setDisplayName("MANUAL_TRANSFER".equals(methodCode)
        ? "Manual transfer"
        : methodCode);
    method.setIsActive(true);
    paymentMethods.save(method);
  }

  @Transactional
  public PaymentItem refund(UUID actor, UUID id, RefundPayment body) {
    AppUser admin = support.actor(actor, true);
    Payment p = lockPayment(id);
    AdminSupportService.state(p.getStatus(), "PAID", "SUCCESS", "COMPLETED");
    if (payments.existsByRefundReference(body.refundReference().trim()))
      throw new ResourceConflictException("Mã hoàn tiền đã được ghi nhận.");
    if (transactions.existsByPayment_PaymentIdAndStatus(id, "COMPLETED"))
      throw new ResourceConflictException(
          "Payment đã giải ngân vào ví; cần đối soát thu hồi khoản giải ngân trước khi ghi nhận"
              + " hoàn tiền.");
    if (p.getSubscription() != null) {
      var s = subscriptions.lockById(p.getSubscription().getSubscriptionId()).orElseThrow();
      s.setStatus("CANCELLED");
      s.setAutoRenew(false);
    }
    p.setStatus("REFUNDED");
    p.setRefundReference(body.refundReference().trim());
    p.setRefundedAt(Instant.now());
    support.audit(
        admin, "MANUAL_REFUND", "PAYMENT", id, body.refundReference() + ": " + body.note());
    support.notify(p.getUser(), "PAYMENT_REFUND", "Đã ghi nhận hoàn tiền", body.note());
    return paymentItem(payments.save(p));
  }

  private void record(AppUser admin, WithdrawalRequest w, String decision, String note) {
    WithdrawalReview r = new WithdrawalReview();
    r.setWithdrawalRequest(w);
    r.setReviewerUser(admin);
    r.setDecision(decision);
    r.setNote(note);
    r.setReviewedAt(Instant.now());
    reviews.save(r);
    support.audit(admin, "WITHDRAWAL_" + decision, "WITHDRAWAL", w.getWithdrawalRequestId(), note);
    support.notify(
        w.getProducerProfile().getUser(),
        "WITHDRAWAL_RESULT",
        "Kết quả yêu cầu rút tiền",
        decision + ": " + note);
  }

  private void requireReserved(WithdrawalRequest w) {
    if (!w.isFundsReserved())
      throw new ResourceConflictException("Không có tiền đang giữ; cần kiểm tra dữ liệu rút tiền.");
  }

  private WalletTransaction hold(UUID id) {
    var transaction =
        transactions
            .findByWithdrawalRequest_WithdrawalRequestIdAndStatus(id, "PENDING")
            .orElseThrow(() -> new ResourceConflictException("Không tìm thấy giao dịch giữ tiền."));
    var request = transaction.getWithdrawalRequest();
    if (transaction.getUserWallet() == null
        || !transaction
            .getUserWallet()
            .getUserWalletId()
            .equals(request.getUserWallet().getUserWalletId())
        || transaction.getAmount().compareTo(request.getAmount()) != 0
        || !transaction.getCurrency().trim().equals(request.getCurrency().trim())
        || !"OUT".equals(transaction.getDirection())
        || !"WITHDRAWAL".equals(transaction.getTransactionType()))
      throw new ResourceConflictException("Giao dịch giữ tiền không khớp yêu cầu rút tiền.");
    return transaction;
  }

  private UserWallet lockWallet(UUID id) {
    return wallets
        .lockById(id)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy ví."));
  }

  private WithdrawalRequest lockWithdrawal(UUID id) {
    return withdrawals
        .lockById(id)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy yêu cầu rút tiền."));
  }

  private WithdrawalRequest requireWithdrawal(UUID id) {
    return withdrawals
        .findById(id)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy yêu cầu rút tiền."));
  }

  private Payment lockPayment(UUID id) {
    return payments
        .lockById(id)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy payment."));
  }

  private WithdrawalItem withdrawalItem(WithdrawalRequest w) {
    return new WithdrawalItem(
        w.getWithdrawalRequestId(),
        w.getProducerProfile().getProducerProfileId(),
        w.getUserWallet().getUserWalletId(),
        w.getAmount(),
        w.getCurrency(),
        w.getPayoutMethod(),
        w.getPayoutAccountMasked(),
        w.getStatus(),
        w.isFundsReserved(),
        w.getPayoutReference(),
        w.getNote(),
        w.getRequestedAt(),
        w.getProcessedAt());
  }

  private PaymentItem paymentItem(Payment p) {
    return new PaymentItem(
        p.getPaymentId(),
        p.getUser().getUserId(),
        p.getSubscription() == null ? null : p.getSubscription().getSubscriptionId(),
        p.getSeriesRequest() == null ? null : p.getSeriesRequest().getSeriesRequestId(),
        p.getContractStage() == null ? null : p.getContractStage().getContractStageId(),
        p.getAmount(),
        p.getCurrency(),
        p.getStatus(),
        p.getProvider(),
        p.getProviderTransactionId(),
        p.getCreatedAt(),
        p.getPaidAt(),
        p.getRefundReference(),
        p.getRefundedAt());
  }
}
