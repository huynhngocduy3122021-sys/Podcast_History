package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.prmteam7.podcasthistory.exception.WalletWorkflowException;
import com.prmteam7.podcasthistory.dto.request.RecordPayoutResultRequest;
import com.prmteam7.podcasthistory.enums.PayoutResult;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;

@ExtendWith(MockitoExtension.class)
class CreatorWalletTransactionsTest {
    @Mock AppUserRepository users;
    @Mock ProducerProfileRepository creators;
    @Mock UserWalletRepository wallets;
    @Mock CreatorPayoutAccountRepository payoutAccounts;
    @Mock WithdrawalRequestRepository withdrawals;
    @Mock WalletTransactionRepository transactions;
    @Mock WalletTransactionRealtimePublisher walletRealtime;
    @Mock PayoutPaymentRepository payments;
    @InjectMocks CreatorWalletService service;

    @Test
    void creatorSeesOwnContractCreditWithPaginationAndStatusFilter() {
        AppUser creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        WalletTransaction credit = new WalletTransaction();
        credit.setWalletTransactionId(UUID.randomUUID());
        credit.setTransactionType("RELEASE_FUNDS");
        credit.setDirection("CREDIT");
        credit.setAmount(new BigDecimal("24000.00"));
        credit.setCurrency("VND");
        credit.setStatus("COMPLETED");
        credit.setReferenceCode("CONTRACT_CREATOR:stage-id");
        credit.setBalanceAfter(new BigDecimal("24000.00"));
        credit.setHeldBalanceAfter(BigDecimal.ZERO);
        credit.setCreatedAt(Instant.now());
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setRequestedTitle("Podcast lịch sử Việt Nam");
        RequestResponse response = new RequestResponse();
        response.setSeriesRequest(request);
        Contract contract = new Contract();
        contract.setSeriesResponse(response);
        ContractStage stage = new ContractStage();
        stage.setContractStageId(UUID.randomUUID());
        stage.setStageName("Bản nháp");
        stage.setContract(contract);
        Payment payment = new Payment();
        payment.setContractStage(stage);
        credit.setPayment(payment);
        when(users.findById(creator.getUserId())).thenReturn(Optional.of(creator));
        when(creators.findByUser_UserId(creator.getUserId())).thenReturn(Optional.of(profile));
        when(transactions.findForUser(eq(creator.getUserId()), eq("COMPLETED"), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(credit)));

        var result = service.transactions(creator.getUserId(), " COMPLETED ", 0, 20);

        assertEquals(1, result.getTotalElements());
        assertEquals("RELEASE_FUNDS", result.getContent().get(0).type());
        assertEquals(new BigDecimal("24000.00"), result.getContent().get(0).amount());
        assertEquals("Nhận tiền đợt: Bản nháp", result.getContent().get(0).title());
        assertEquals("AVAILABLE_CREDIT", result.getContent().get(0).movement());
        assertEquals(new BigDecimal("24000.00"), result.getContent().get(0).availableBalanceChange());
        assertEquals(request.getSeriesRequestId(), result.getContent().get(0).requestId());
        assertEquals("Podcast lịch sử Việt Nam", result.getContent().get(0).requestTitle());
        assertEquals(stage.getContractStageId(), result.getContent().get(0).milestoneId());
        verify(transactions).findForUser(eq(creator.getUserId()), eq("COMPLETED"),
                argThat(pageable -> pageable.getPageNumber() == 0
                        && pageable.getPageSize() == 20
                        && pageable.getSort().getOrderFor("createdAt") != null));
    }

    @Test
    void listenerCannotReadCreatorTransactionEndpoint() {
        AppUser listener = user("LISTENER");
        when(users.findById(listener.getUserId())).thenReturn(Optional.of(listener));

        assertThrows(WalletWorkflowException.class,
                () -> service.transactions(listener.getUserId(), null, 0, 20));

        verifyNoInteractions(transactions);
    }

    @Test
    void withdrawalHistoryShowsHoldSettlementAndRefundFromTheCorrectBalance() {
        AppUser creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        WithdrawalRequest withdrawal = new WithdrawalRequest();
        withdrawal.setWithdrawalRequestId(UUID.randomUUID());
        withdrawal.setPayoutAccountMasked("****1234");
        WithdrawalRequest failedWithdrawal = new WithdrawalRequest();
        failedWithdrawal.setWithdrawalRequestId(UUID.randomUUID());
        failedWithdrawal.setPayoutAccountMasked("****5678");
        WalletTransaction hold = transaction("WITHDRAWAL_HOLD", "DEBIT", "40000", withdrawal);
        WalletTransaction payout = transaction("WITHDRAWAL_SETTLEMENT", "DEBIT", "40000", withdrawal);
        WalletTransaction refund = transaction("WITHDRAWAL_REFUND", "CREDIT", "40000", failedWithdrawal);
        when(users.findById(creator.getUserId())).thenReturn(Optional.of(creator));
        when(creators.findByUser_UserId(creator.getUserId())).thenReturn(Optional.of(profile));
        when(transactions.findForUser(eq(creator.getUserId()), isNull(), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(hold, payout, refund)));

        var items = service.transactions(creator.getUserId(), null, 0, 20).getContent();

        assertEquals("AVAILABLE_TO_HELD", items.get(0).movement());
        assertEquals(new BigDecimal("-40000"), items.get(0).availableBalanceChange());
        assertEquals(new BigDecimal("40000"), items.get(0).heldBalanceChange());
        assertEquals("HELD_TO_PAYOUT", items.get(1).movement());
        assertEquals(BigDecimal.ZERO.setScale(2), items.get(1).availableBalanceChange());
        assertEquals(new BigDecimal("-40000"), items.get(1).heldBalanceChange());
        assertEquals("HELD_TO_AVAILABLE", items.get(2).movement());
        assertEquals(new BigDecimal("40000"), items.get(2).availableBalanceChange());
        assertEquals(new BigDecimal("-40000"), items.get(2).heldBalanceChange());
        assertEquals(withdrawal.getWithdrawalRequestId(), items.get(1).withdrawalId());
        assertEquals("****1234", items.get(1).payoutAccountMasked());
        assertEquals(failedWithdrawal.getWithdrawalRequestId(), items.get(2).withdrawalId());
    }

    @Test
    void membershipIncomeNamesThePlanAndAvailableCredit() {
        AppUser creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        MembershipPlan plan = new MembershipPlan();
        plan.setName("Thành viên kênh");
        Subscription subscription = new Subscription();
        subscription.setMembershipPlan(plan);
        Payment payment = new Payment();
        payment.setSubscription(subscription);
        WalletTransaction earning = transaction("MEMBERSHIP_EARNING", "CREDIT", "20000", null);
        earning.setPayment(payment);
        when(users.findById(creator.getUserId())).thenReturn(Optional.of(creator));
        when(creators.findByUser_UserId(creator.getUserId())).thenReturn(Optional.of(profile));
        when(transactions.findForUser(eq(creator.getUserId()), isNull(), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(earning)));

        var item = service.transactions(creator.getUserId(), null, 0, 20).getContent().get(0);

        assertEquals("Doanh thu membership: Thành viên kênh", item.title());
        assertEquals("Thành viên kênh", item.membershipPlanName());
        assertEquals("AVAILABLE_CREDIT", item.movement());
        assertEquals(new BigDecimal("20000"), item.availableBalanceChange());
        assertEquals(BigDecimal.ZERO.setScale(2), item.heldBalanceChange());
    }

    @Test
    void successfulPayoutRecordsHeldToBankWithoutChangingOriginalHoldSnapshot() {
        AppUser admin = user("ADMIN");
        AppUser creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        UserWallet wallet = new UserWallet();
        wallet.setBalance(new BigDecimal("60000"));
        wallet.setHeldBalance(new BigDecimal("40000"));
        wallet.setCurrency("VND");
        WithdrawalRequest withdrawal = new WithdrawalRequest();
        UUID withdrawalId = UUID.randomUUID();
        withdrawal.setWithdrawalRequestId(withdrawalId);
        withdrawal.setProducerProfile(profile);
        withdrawal.setAmount(new BigDecimal("40000"));
        withdrawal.setCurrency("VND");
        withdrawal.setStatus("PENDING");
        WalletTransaction hold = transaction("WITHDRAWAL_HOLD", "DEBIT", "40000", withdrawal);
        hold.setBalanceAfter(new BigDecimal("60000"));
        hold.setHeldBalanceAfter(new BigDecimal("40000"));
        when(users.findByIdForUpdate(admin.getUserId())).thenReturn(Optional.of(admin));
        when(withdrawals.findByIdForUpdate(withdrawalId)).thenReturn(Optional.of(withdrawal));
        when(wallets.findByUserIdForUpdate(creator.getUserId())).thenReturn(Optional.of(wallet));
        when(transactions.findFirstByWithdrawalRequest_WithdrawalRequestIdAndTransactionType(
                withdrawalId, "WITHDRAWAL_HOLD")).thenReturn(Optional.of(hold));
        when(withdrawals.save(withdrawal)).thenReturn(withdrawal);

        service.recordPayoutResult(admin.getUserId(), withdrawalId,
                new RecordPayoutResultRequest(PayoutResult.SUCCESS, "bank-123", null));

        assertEquals(new BigDecimal("60000"), wallet.getBalance());
        assertEquals(BigDecimal.ZERO, wallet.getHeldBalance());
        assertEquals("COMPLETED", hold.getStatus());
        assertEquals(new BigDecimal("40000"), hold.getHeldBalanceAfter());
        verify(transactions).save(argThat(transaction ->
                "WITHDRAWAL_SETTLEMENT".equals(transaction.getTransactionType())
                && transaction.getHeldBalanceAfter().compareTo(BigDecimal.ZERO) == 0));
    }

    private WalletTransaction transaction(String type, String direction, String amount,
            WithdrawalRequest withdrawal) {
        WalletTransaction transaction = new WalletTransaction();
        transaction.setTransactionType(type);
        transaction.setDirection(direction);
        transaction.setAmount(new BigDecimal(amount));
        transaction.setCurrency("VND");
        transaction.setStatus("COMPLETED");
        transaction.setWithdrawalRequest(withdrawal);
        return transaction;
    }

    private AppUser user(String roleCode) {
        Role role = new Role();
        role.setRoleCode(roleCode);
        AppUser user = new AppUser();
        user.setUserId(UUID.randomUUID());
        user.setRole(role);
        user.setIsActive(true);
        return user;
    }
}
