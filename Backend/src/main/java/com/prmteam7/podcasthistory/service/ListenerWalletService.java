package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.response.CheckoutPaymentView;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.WalletTransactionItem;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.math.BigDecimal;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ListenerWalletService {
  private final AppUserRepository users;
  private final UserWalletRepository wallets;
  private final WalletTransactionRepository transactions;
  private final CheckoutPaymentRepository checkouts;
  private final PaymentMethodRepository paymentMethods;
  private final SeriesRequestRepository requests;
  private final SepayService sepay;

  public ListenerWalletService(AppUserRepository users, UserWalletRepository wallets,
      WalletTransactionRepository transactions, CheckoutPaymentRepository checkouts,
      PaymentMethodRepository paymentMethods, SeriesRequestRepository requests, SepayService sepay) {
    this.users = users;
    this.wallets = wallets;
    this.transactions = transactions;
    this.checkouts = checkouts;
    this.paymentMethods = paymentMethods;
    this.requests = requests;
    this.sepay = sepay;
  }

  @Transactional
  public UserWallet balance(UUID userId) {
    AppUser user = users.findByIdForUpdate(userId)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng."));
    requireListener(user);
    return walletForLockedUser(user);
  }

  @Transactional
  public CheckoutPaymentView topUp(UUID userId, BigDecimal amount) {
    if (amount == null || amount.scale() > 0 || amount.compareTo(new BigDecimal("10000")) < 0
        || amount.compareTo(new BigDecimal("100000000")) > 0)
      throw new ResourceConflictException("Số tiền nạp phải là VND nguyên từ 10.000 đến 100.000.000.");
    AppUser user = users.findByIdForUpdate(userId)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng."));
    requireListener(user);
    walletForLockedUser(user);
    String code = sepay.generatePaymentCode();
    String qr = sepay.createQrImageUrl(amount, code);
    CheckoutPayment checkout = new CheckoutPayment();
    checkout.setUser(user);
    checkout.setPurpose("WALLET_TOPUP");
    checkout.setAmount(amount);
    checkout.setCurrency("VND");
    checkout.setPaymentCode(code);
    checkout.setStatus("PENDING");
    checkout = checkouts.saveAndFlush(checkout);
    return new CheckoutPaymentView(checkout.getCheckoutId(), null, checkout.getPurpose(), code,
        qr, amount, "VND", checkout.getStatus(), null,
        checkout.getCreatedAt().plus(30, ChronoUnit.MINUTES));
  }

  @Transactional(readOnly = true)
  public Page<WalletTransactionItem> transactions(UUID userId, String status, int page, int size) {
    AppUser user = users.findById(userId)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng."));
    requireListener(user);
    String normalizedStatus = status == null ? null : status.trim();
    if (normalizedStatus != null && normalizedStatus.isBlank()) normalizedStatus = null;
    Pageable pageable = PageRequest.of(
        Math.max(0, page),
        Math.min(100, Math.max(1, size)),
        Sort.by(Sort.Direction.DESC, "createdAt"));
    Page<WalletTransaction> result = transactions.findForUser(userId, normalizedStatus, pageable);
    Map<UUID, String> requestTitles = new HashMap<>();
    var requestIds = result.getContent().stream()
        .filter(transaction -> "CONTRACT_HOLD".equals(transaction.getTransactionType())
            || "CONTRACT_REFUND".equals(transaction.getTransactionType()))
        .map(transaction -> requestIdFromReference(transaction.getReferenceCode()))
        .filter(Objects::nonNull).distinct().toList();
    if (!requestIds.isEmpty()) {
      requests.findAllById(requestIds).forEach(request -> {
        if (userId.equals(request.getUser().getUserId()))
          requestTitles.put(request.getSeriesRequestId(), request.getRequestedTitle());
      });
    }
    return result.map(transaction -> toTransactionItem(transaction, requestTitles));
  }

  private WalletTransactionItem toTransactionItem(WalletTransaction transaction,
      Map<UUID, String> requestTitles) {
    String type = transaction.getTransactionType();
    BigDecimal amount = transaction.getAmount();
    BigDecimal availableChange = null;
    BigDecimal heldChange = null;
    String movement = null;
    String title;
    String description;
    UUID requestId = null;
    String requestTitle = null;
    UUID milestoneId = null;
    String milestoneName = null;
    Payment payment = transaction.getPayment();
    ContractStage stage = payment == null ? null : payment.getContractStage();
    if (stage != null) {
      milestoneId = stage.getContractStageId();
      milestoneName = stage.getStageName();
      SeriesRequest request = stage.getContract().getSeriesResponse().getSeriesRequest();
      requestId = request.getSeriesRequestId();
      requestTitle = request.getRequestedTitle();
    } else if (payment != null && payment.getSeriesRequest() != null) {
      SeriesRequest request = payment.getSeriesRequest();
      requestId = request.getSeriesRequestId();
      requestTitle = request.getRequestedTitle();
    } else if ("CONTRACT_HOLD".equals(type) || "CONTRACT_REFUND".equals(type)) {
      requestId = requestIdFromReference(transaction.getReferenceCode());
      requestTitle = requestTitles.get(requestId);
    }
    switch (type) {
      case "CONTRACT_HOLD" -> {
        title = requestTitle == null ? "Giữ ngân sách cho yêu cầu"
            : "Giữ ngân sách: " + requestTitle;
        description = "Chuyển tiền từ số dư khả dụng sang tiền đang giữ; chưa trả cho CC.";
        movement = "AVAILABLE_TO_HELD";
        availableChange = amount.negate();
        heldChange = amount;
      }
      case "CONTRACT_STAGE_DEBIT" -> {
        title = stage == null ? "Giải ngân một đợt hợp đồng"
            : "Giải ngân đợt " + stage.getStageOrder() + ": " + stage.getStageName();
        description = "Chi từ tiền đã giữ cho đợt này; không trừ thêm số dư khả dụng.";
        movement = "HELD_TO_SETTLEMENT";
        availableChange = BigDecimal.ZERO;
        heldChange = amount.negate();
      }
      case "CONTRACT_COMPENSATION_DEBIT" -> {
        title = "Chi đền công cho CC từ tiền giữ";
        description = "Chi khoản đền công từ tiền đã giữ; không trừ thêm số dư khả dụng.";
        movement = "HELD_TO_SETTLEMENT";
        availableChange = BigDecimal.ZERO;
        heldChange = amount.negate();
      }
      case "CONTRACT_DISPUTE_DEBIT" -> {
        title = "Giải ngân cho CC sau tranh chấp";
        description = "Chi từ tiền đã giữ theo kết quả tranh chấp; không trừ thêm số dư khả dụng.";
        movement = "HELD_TO_SETTLEMENT";
        availableChange = BigDecimal.ZERO;
        heldChange = amount.negate();
      }
      case "CONTRACT_REFUND" -> {
        title = requestTitle == null ? "Hoàn ngân sách chưa chi"
            : "Hoàn ngân sách: " + requestTitle;
        description = "Chuyển tiền còn giữ của hợp đồng về số dư khả dụng.";
        movement = "HELD_TO_AVAILABLE";
        availableChange = amount;
        heldChange = amount.negate();
      }
      case "WALLET_TOPUP" -> {
        title = "Nạp tiền vào ví";
        description = "Tiền nạp được cộng vào số dư khả dụng.";
        movement = "AVAILABLE_CREDIT";
        availableChange = amount;
        heldChange = BigDecimal.ZERO;
      }
      case "MEMBERSHIP_PURCHASE" -> {
        title = "Thanh toán gói thành viên";
        description = "Trả phí gói thành viên từ số dư khả dụng.";
        movement = "AVAILABLE_DEBIT";
        availableChange = amount.negate();
        heldChange = BigDecimal.ZERO;
      }
      case "ADMIN_BALANCE_ADJUSTMENT" -> {
        title = "Điều chỉnh số dư ví";
        description = "Số dư khả dụng được điều chỉnh bởi quản trị viên.";
        boolean credit = "CREDIT".equalsIgnoreCase(transaction.getDirection());
        movement = credit ? "AVAILABLE_CREDIT" : "AVAILABLE_DEBIT";
        availableChange = credit ? amount : amount.negate();
        heldChange = BigDecimal.ZERO;
      }
      case "REFUND" -> {
        title = "Hoàn tiền vào ví";
        description = "Khoản hoàn được cộng vào số dư khả dụng.";
        movement = "AVAILABLE_CREDIT";
        availableChange = amount;
        heldChange = BigDecimal.ZERO;
      }
      default -> {
        title = "Giao dịch ví: " + type;
        description = "Kiểm tra mã tham chiếu và biến động số dư của giao dịch này.";
      }
    }
    return new WalletTransactionItem(transaction.getWalletTransactionId(), type,
        transaction.getDirection(), amount, transaction.getCurrency(), transaction.getStatus(),
        transaction.getReferenceCode(), transaction.getBalanceAfter(),
        transaction.getHeldBalanceAfter(), transaction.getCreatedAt(), title, description,
        movement, availableChange, heldChange, requestId, requestTitle,
        milestoneId, milestoneName);
  }

  private UUID requestIdFromReference(String reference) {
    if (reference == null) return null;
    int separator = reference.lastIndexOf(':');
    if (separator < 0) return null;
    try { return UUID.fromString(reference.substring(separator + 1)); }
    catch (IllegalArgumentException exception) { return null; }
  }

  public UserWallet walletForLockedUser(AppUser user) {
    requireListener(user);
    UserWallet wallet = wallets.findByUserIdForUpdate(user.getUserId()).orElseGet(() -> {
      UserWallet created = new UserWallet();
      created.setUser(user);
      created.setBalance(BigDecimal.ZERO);
      created.setHeldBalance(BigDecimal.ZERO);
      created.setCurrency("VND");
      created.setStatus("ACTIVE");
      return wallets.saveAndFlush(created);
    });
    if (!"ACTIVE".equalsIgnoreCase(wallet.getStatus()) || !"VND".equalsIgnoreCase(wallet.getCurrency().trim()))
      throw new ResourceConflictException("Ví chưa hoạt động hoặc không dùng VND.");
    return wallet;
  }

  private void requireListener(AppUser user) {
    if (!Boolean.TRUE.equals(user.getIsActive()) ||
        !"LISTENER".equalsIgnoreCase(user.getRole().getRoleCode()))
      throw new ResourceConflictException("Ví nạp tiền hiện chỉ dành cho Listener đang hoạt động.");
  }

  public void debit(UserWallet wallet, Payment payment) {
    BigDecimal amount = payment.getAmount();
    if (wallet.getBalance().compareTo(amount) < 0)
      throw new ResourceConflictException("Số dư ví không đủ.");
    wallet.setBalance(wallet.getBalance().subtract(amount));
    wallets.save(wallet);
    record(wallet, payment, "MEMBERSHIP_PURCHASE", "DEBIT", amount);
    PaymentMethod method = new PaymentMethod();
    method.setPayment(payment);
    method.setMethodCode("WALLET");
    method.setDisplayName("Listener wallet");
    method.setIsActive(true);
    paymentMethods.save(method);
  }

  private void record(UserWallet wallet, Payment payment, String type, String direction, BigDecimal amount) {
    WalletTransaction transaction = new WalletTransaction();
    transaction.setUserWallet(wallet);
    transaction.setPayment(payment);
    transaction.setTransactionType(type);
    transaction.setDirection(direction);
    transaction.setAmount(amount);
    transaction.setCurrency("VND");
    transaction.setReferenceCode("MEMBERSHIP:" + payment.getPaymentId());
    transaction.setStatus("COMPLETED");
    transaction.setBalanceAfter(wallet.getBalance());
    transaction.setHeldBalanceAfter(wallet.getHeldBalance());
    transactions.save(transaction);
  }
}
