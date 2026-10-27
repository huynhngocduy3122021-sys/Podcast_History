package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.response.CheckoutPaymentView;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.math.BigDecimal;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ListenerWalletService {
  private final AppUserRepository users;
  private final UserWalletRepository wallets;
  private final WalletTransactionRepository transactions;
  private final CheckoutPaymentRepository checkouts;
  private final PaymentMethodRepository paymentMethods;
  private final SepayService sepay;

  public ListenerWalletService(AppUserRepository users, UserWalletRepository wallets,
      WalletTransactionRepository transactions, CheckoutPaymentRepository checkouts,
      PaymentMethodRepository paymentMethods, SepayService sepay) {
    this.users = users;
    this.wallets = wallets;
    this.transactions = transactions;
    this.checkouts = checkouts;
    this.paymentMethods = paymentMethods;
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
