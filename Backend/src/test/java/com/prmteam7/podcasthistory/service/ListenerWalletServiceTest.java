package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.model.Payment;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.Contract;
import com.prmteam7.podcasthistory.model.ContractStage;
import com.prmteam7.podcasthistory.model.RequestResponse;
import com.prmteam7.podcasthistory.model.Role;
import com.prmteam7.podcasthistory.model.SeriesRequest;
import com.prmteam7.podcasthistory.model.UserWallet;
import com.prmteam7.podcasthistory.model.WalletTransaction;
import com.prmteam7.podcasthistory.repository.*;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.PageImpl;
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
  @Mock WalletTransactionRealtimePublisher walletRealtime;
  @Mock SeriesRequestRepository requests;
  ListenerWalletService service;

  @BeforeEach
  void setUp() {
    service = new ListenerWalletService(users, wallets, transactions, checkouts, paymentMethods,
        requests, sepay, walletRealtime);
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

  @Test
  void contractHistoryExplainsHeldMoneyWithoutSecondAvailableDebit() {
    UUID userId = UUID.randomUUID();
    UUID requestId = UUID.randomUUID();
    AppUser listener = new AppUser();
    listener.setUserId(userId);
    listener.setIsActive(true);
    Role role = new Role();
    role.setRoleCode("LISTENER");
    listener.setRole(role);
    SeriesRequest request = new SeriesRequest();
    request.setSeriesRequestId(requestId);
    request.setUser(listener);
    request.setRequestedTitle("Podcast lịch sử Việt Nam");
    Contract contract = new Contract();
    RequestResponse response = new RequestResponse();
    response.setSeriesRequest(request);
    contract.setSeriesResponse(response);
    ContractStage stage = new ContractStage();
    stage.setContractStageId(UUID.randomUUID());
    stage.setContract(contract);
    stage.setStageOrder(1);
    stage.setStageName("Bản nháp");
    Payment payment = new Payment();
    payment.setContractStage(stage);

    WalletTransaction hold = transaction("CONTRACT_HOLD", "DEBIT", "100000",
        "CONTRACT_HOLD:" + requestId, null);
    WalletTransaction payout = transaction("CONTRACT_STAGE_DEBIT", "DEBIT", "40000",
        "CONTRACT_STAGE:" + stage.getContractStageId(), payment);
    WalletTransaction refund = transaction("CONTRACT_REFUND", "CREDIT", "60000",
        "CONTRACT_DISPUTE_REFUND:" + requestId, null);
    when(users.findById(userId)).thenReturn(java.util.Optional.of(listener));
    when(transactions.findForUser(eq(userId), isNull(), any()))
        .thenReturn(new PageImpl<>(List.of(hold, payout, refund)));
    when(requests.findAllById(any())).thenReturn(List.of(request));

    var items = service.transactions(userId, null, 0, 20).getContent();

    assertEquals("AVAILABLE_TO_HELD", items.get(0).movement());
    assertEquals(new BigDecimal("-100000"), items.get(0).availableBalanceChange());
    assertEquals(new BigDecimal("100000"), items.get(0).heldBalanceChange());
    assertEquals(requestId, items.get(0).requestId());
    assertEquals("Podcast lịch sử Việt Nam", items.get(0).requestTitle());
    assertEquals("Giữ ngân sách: Podcast lịch sử Việt Nam", items.get(0).title());
    assertEquals("HELD_TO_SETTLEMENT", items.get(1).movement());
    assertEquals(BigDecimal.ZERO, items.get(1).availableBalanceChange());
    assertEquals(new BigDecimal("-40000"), items.get(1).heldBalanceChange());
    assertEquals(stage.getContractStageId(), items.get(1).milestoneId());
    assertEquals("Giải ngân đợt 1: Bản nháp", items.get(1).title());
    assertTrue(items.get(1).description().contains("không trừ thêm số dư khả dụng"));
    assertEquals("HELD_TO_AVAILABLE", items.get(2).movement());
    assertEquals(new BigDecimal("60000"), items.get(2).availableBalanceChange());
    assertEquals(new BigDecimal("-60000"), items.get(2).heldBalanceChange());
    assertEquals("Hoàn ngân sách: Podcast lịch sử Việt Nam", items.get(2).title());
    assertEquals(new BigDecimal("-40000"), items.stream()
        .map(item -> item.availableBalanceChange()).reduce(BigDecimal.ZERO, BigDecimal::add));
  }

  private WalletTransaction transaction(String type, String direction, String amount,
      String reference, Payment payment) {
    WalletTransaction transaction = new WalletTransaction();
    transaction.setWalletTransactionId(UUID.randomUUID());
    transaction.setTransactionType(type);
    transaction.setDirection(direction);
    transaction.setAmount(new BigDecimal(amount));
    transaction.setCurrency("VND");
    transaction.setStatus("COMPLETED");
    transaction.setReferenceCode(reference);
    transaction.setPayment(payment);
    return transaction;
  }
}
