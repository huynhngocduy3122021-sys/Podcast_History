package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.Payment;
import com.prmteam7.podcasthistory.model.UserWallet;
import com.prmteam7.podcasthistory.model.WalletTransaction;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.UserWalletRepository;
import com.prmteam7.podcasthistory.repository.WalletTransactionRepository;
import java.math.BigDecimal;
import java.math.RoundingMode;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MembershipRevenueService {
  private static final BigDecimal PLATFORM_RATE = new BigDecimal("0.20");
  private final AppUserRepository users;
  private final UserWalletRepository wallets;
  private final WalletTransactionRepository transactions;

  public MembershipRevenueService(AppUserRepository users, UserWalletRepository wallets,
      WalletTransactionRepository transactions) {
    this.users = users;
    this.wallets = wallets;
    this.transactions = transactions;
  }

  @Transactional
  public void creditPaidMembership(Payment payment) {
    if (payment.getSubscription() == null || payment.getPaymentId() == null
        || !"PAID".equalsIgnoreCase(payment.getStatus())
        || !"VND".equalsIgnoreCase(payment.getCurrency().trim())
        || payment.getAmount().signum() <= 0)
      throw new IllegalArgumentException("Payment membership đã thanh toán không hợp lệ.");
    AppUser creator = payment.getSubscription().getMembershipPlan().getProducerProfile().getUser();
    users.findByIdForUpdate(creator.getUserId()).orElseThrow();
    if (transactions.existsByPayment_PaymentIdAndTransactionType(payment.getPaymentId(), "MEMBERSHIP_EARNING"))
      return;
    UserWallet wallet = wallets.findByUserIdForUpdate(creator.getUserId()).orElseGet(() -> {
      UserWallet created = new UserWallet();
      created.setUser(creator);
      created.setBalance(BigDecimal.ZERO);
      created.setHeldBalance(BigDecimal.ZERO);
      created.setCurrency("VND");
      created.setStatus("ACTIVE");
      return wallets.saveAndFlush(created);
    });
    if (!"ACTIVE".equalsIgnoreCase(wallet.getStatus()))
      throw new IllegalStateException("Ví Creator không hoạt động.");
    if (!"VND".equalsIgnoreCase(wallet.getCurrency().trim())) {
      if (wallet.getBalance().signum() != 0 || wallet.getHeldBalance().signum() != 0)
        throw new IllegalStateException("Ví Creator dùng tiền tệ khác VND; cần đối soát.");
      wallet.setCurrency("VND");
    }
    BigDecimal fee = payment.getAmount().multiply(PLATFORM_RATE)
        .setScale(0, RoundingMode.HALF_UP).setScale(2);
    BigDecimal net = payment.getAmount().subtract(fee);
    wallet.setBalance(wallet.getBalance().add(net));
    wallets.save(wallet);
    transactions.save(transaction(wallet, payment, "MEMBERSHIP_EARNING", "CREDIT", net,
        "MEMBERSHIP_CREATOR:" + payment.getPaymentId()));
    if (fee.signum() > 0)
      transactions.save(transaction(null, payment, "PLATFORM_FEE", "CREDIT", fee,
          "MEMBERSHIP_FEE:" + payment.getPaymentId()));
  }

  private WalletTransaction transaction(UserWallet wallet, Payment payment, String type,
      String direction, BigDecimal amount, String reference) {
    WalletTransaction transaction = new WalletTransaction();
    transaction.setUserWallet(wallet);
    transaction.setPayment(payment);
    transaction.setTransactionType(type);
    transaction.setDirection(direction);
    transaction.setAmount(amount);
    transaction.setCurrency(payment.getCurrency());
    transaction.setStatus("COMPLETED");
    transaction.setReferenceCode(reference);
    if (wallet != null) {
      transaction.setBalanceAfter(wallet.getBalance());
      transaction.setHeldBalanceAfter(wallet.getHeldBalance());
    }
    return transaction;
  }
}
