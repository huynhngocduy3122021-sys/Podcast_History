package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.model.Payment;
import com.prmteam7.podcasthistory.model.UserWallet;
import com.prmteam7.podcasthistory.repository.*;
import java.math.BigDecimal;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ListenerWalletServiceTest {
  @Mock AppUserRepository users;
  @Mock UserWalletRepository wallets;
  @Mock WalletTransactionRepository transactions;
  @Mock CheckoutPaymentRepository checkouts;
  @Mock PaymentMethodRepository paymentMethods;
  @Mock SepayService sepay;
  ListenerWalletService service;

  @BeforeEach
  void setUp() {
    service = new ListenerWalletService(users, wallets, transactions, checkouts, paymentMethods, sepay);
  }

  @Test
  void insufficientBalanceDoesNotDebitOrRecordPayment() {
    UserWallet wallet = new UserWallet();
    wallet.setBalance(new BigDecimal("40000"));
    Payment payment = new Payment();
    payment.setPaymentId(UUID.randomUUID());
    payment.setAmount(new BigDecimal("50000"));

    assertThrows(ResourceConflictException.class, () -> service.debit(wallet, payment));

    assertEquals(new BigDecimal("40000"), wallet.getBalance());
    verifyNoInteractions(wallets, transactions, paymentMethods);
  }

  @Test
  void successfulMembershipPurchaseDebitsWalletAndRecordsPayment() {
    UserWallet wallet = new UserWallet();
    wallet.setBalance(new BigDecimal("90000"));
    wallet.setHeldBalance(BigDecimal.ZERO);
    Payment payment = new Payment();
    payment.setPaymentId(UUID.randomUUID());
    payment.setAmount(new BigDecimal("50000"));

    service.debit(wallet, payment);

    assertEquals(new BigDecimal("40000"), wallet.getBalance());
    verify(wallets).save(wallet);
    verify(transactions).save(org.mockito.ArgumentMatchers.any());
    verify(paymentMethods).save(org.mockito.ArgumentMatchers.any());
  }

  @Test
  void rejectsTopUpOutsideAllowedRangeBeforeCreatingCheckout() {
    assertThrows(ResourceConflictException.class,
        () -> service.topUp(UUID.randomUUID(), new BigDecimal("1000")));
    verifyNoInteractions(users, wallets, transactions, checkouts, paymentMethods, sepay);
  }
}
