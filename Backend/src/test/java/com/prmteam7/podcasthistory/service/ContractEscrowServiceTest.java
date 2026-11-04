package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import com.prmteam7.podcasthistory.dto.request.ContractWorkflowRequests;
import com.prmteam7.podcasthistory.enums.ContractStageStatus;
import com.prmteam7.podcasthistory.enums.ListenerWinAction;
import com.prmteam7.podcasthistory.exception.PodcastWorkflowException;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;
import java.util.List;
import java.util.ArrayList;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ContractEscrowServiceTest {
    @Mock AppUserRepository users;
    @Mock ProducerProfileRepository creators;
    @Mock SeriesRequestRepository requests;
    @Mock RequestResponseRepository responses;
    @Mock ContractRepository contracts;
    @Mock ContractStageRepository stages;
    @Mock ContractEscrowRepository escrows;
    @Mock UserWalletRepository wallets;
    @Mock WalletTransactionRepository transactions;
    @Mock PaymentRepository payments;
    @Mock PaymentMethodRepository paymentMethods;
    @Mock ListenerWalletService listenerWallets;
    @Mock ContractDisputeRepository contractDisputes;
    @Mock MilestoneSubmissionRepository submissions;
    @Mock AdminDisputeService adminDisputes;
    @InjectMocks ContractEscrowService service;

    @Test
    void listenerWinRefundsAllRemainingEscrowAndTerminatesContract() {
        AppUser listener = user("LISTENER");
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setUser(listener);
        contract.setStatus("IN_PROGRESS");
        ContractStage stage = new ContractStage();
        stage.setContractStageId(UUID.randomUUID());
        stage.setContract(contract);
        stage.setAmount(new BigDecimal("40000"));
        stage.setStatus("DISPUTED");
        ContractEscrow escrow = new ContractEscrow();
        escrow.setContract(contract);
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setUser(listener);
        escrow.setRequest(request);
        escrow.setRemaining(new BigDecimal("100000"));
        escrow.setFundsHeld(true);
        UserWallet wallet = wallet(listener, "0", "100000");
        when(contracts.lockById(contract.getContractId())).thenReturn(Optional.of(contract));
        when(escrows.lockByContractId(contract.getContractId())).thenReturn(Optional.of(escrow));
        when(stages.lockAllByContractId(contract.getContractId())).thenReturn(List.of(stage));
        when(users.findByIdForUpdate(listener.getUserId())).thenReturn(Optional.of(listener));
        when(listenerWallets.walletForLockedUser(listener)).thenReturn(wallet);

        BigDecimal refunded = service.resolveListenerWin(contract.getContractId(),
                ListenerWinAction.REFUND_STAGE_CONTINUE, stage.getContractStageId());

        assertEquals(0, refunded.compareTo(new BigDecimal("100000")));
        assertEquals(0, wallet.getBalance().compareTo(new BigDecimal("100000")));
        assertEquals(0, wallet.getHeldBalance().compareTo(BigDecimal.ZERO));
        assertEquals(0, escrow.getRemaining().compareTo(BigDecimal.ZERO));
        assertEquals("CANCELLED", stage.getStatus());
        assertEquals("TERMINATED", contract.getStatus());
        verify(transactions).save(argThat(t -> "CONTRACT_REFUND".equals(t.getTransactionType())));
        assertThrows(PodcastWorkflowException.class, () -> service.resolveListenerWin(
                contract.getContractId(), ListenerWinAction.REFUND_STAGE_CONTINUE,
                stage.getContractStageId()));
    }

    @Test
    void creatorWinReceivesAllRemainingEscrowMinusTwentyPercentFee() {
        AppUser listener = user("LISTENER");
        AppUser creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setUser(listener);
        contract.setProducerProfile(profile);
        contract.setStatus("DISPUTED");
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setUser(listener);
        ContractEscrow escrow = new ContractEscrow();
        escrow.setContract(contract);
        escrow.setRequest(request);
        escrow.setFundsHeld(true);
        escrow.setRemaining(new BigDecimal("70000"));
        ContractStage paid = new ContractStage();
        paid.setStatus("APPROVED");
        ContractStage disputed = new ContractStage();
        disputed.setStatus("DISPUTED");
        UserWallet listenerWallet = wallet(listener, "0", "70000");
        UserWallet creatorWallet = wallet(creator, "0", "0");
        when(contracts.lockById(contract.getContractId())).thenReturn(Optional.of(contract));
        when(escrows.lockByContractId(contract.getContractId())).thenReturn(Optional.of(escrow));
        when(stages.lockAllByContractId(contract.getContractId())).thenReturn(List.of(paid, disputed));
        when(users.findByIdForUpdate(listener.getUserId())).thenReturn(Optional.of(listener));
        when(users.findByIdForUpdate(creator.getUserId())).thenReturn(Optional.of(creator));
        when(listenerWallets.walletForLockedUser(listener)).thenReturn(listenerWallet);
        when(wallets.findByUserIdForUpdate(creator.getUserId())).thenReturn(Optional.of(creatorWallet));
        when(payments.saveAndFlush(any(Payment.class))).thenAnswer(call -> {
            Payment saved = call.getArgument(0);
            saved.setPaymentId(UUID.randomUUID());
            return saved;
        });

        BigDecimal released = service.resolveCreatorWin(contract.getContractId());

        assertEquals(0, released.compareTo(new BigDecimal("70000")));
        assertEquals(0, creatorWallet.getBalance().compareTo(new BigDecimal("56000")));
        assertEquals(0, listenerWallet.getHeldBalance().compareTo(BigDecimal.ZERO));
        assertEquals(0, escrow.getRemaining().compareTo(BigDecimal.ZERO));
        assertEquals("TERMINATED", contract.getStatus());
        assertEquals("APPROVED", paid.getStatus());
        assertEquals("CANCELLED", disputed.getStatus());
        verify(transactions).save(argThat(t -> "PLATFORM_FEE".equals(t.getTransactionType())
                && t.getAmount().compareTo(new BigDecimal("14000")) == 0));
        verify(payments).saveAndFlush(argThat(p -> p.getAmount().compareTo(new BigDecimal("70000")) == 0
                && "WALLET_ESCROW_DISPUTE".equals(p.getPaymentMethod())));
        assertThrows(PodcastWorkflowException.class, () -> service.resolveCreatorWin(contract.getContractId()));
    }

    @Test
    void creatingContractRequestDoesNotHoldBudget() {
        AppUser listener = user("LISTENER");
        AppUser creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setProducerProfileId(UUID.randomUUID());
        profile.setUser(creator);
        profile.setVerificationStatus("APPROVED");
        UserWallet wallet = wallet(listener, "150000", "0");
        when(users.findByIdForUpdate(listener.getUserId())).thenReturn(Optional.of(listener));
        when(creators.findById(profile.getProducerProfileId())).thenReturn(Optional.of(profile));
        when(requests.saveAndFlush(any(SeriesRequest.class))).thenAnswer(call -> {
            SeriesRequest request = call.getArgument(0);
            request.setSeriesRequestId(UUID.randomUUID());
            return request;
        });

        var result = service.create(listener.getUserId(), new ContractWorkflowRequests.Create(
                UUID.randomUUID(),
                profile.getProducerProfileId(), "Audio lịch sử", "Mô tả", new BigDecimal("100000"),
                "AUDIO", "MP3", "10 phút", "Âm thanh rõ", false));

        assertEquals(0, result.heldAmount().compareTo(BigDecimal.ZERO));
        assertEquals("Audio lịch sử", result.requestedTitle());
        assertEquals(profile.getProducerProfileId(), result.creatorProfileId());
        assertEquals(listener.getUserId(), result.listenerId());
        assertEquals(0, wallet.getBalance().compareTo(new BigDecimal("150000")));
        assertEquals(0, wallet.getHeldBalance().compareTo(BigDecimal.ZERO));
        verify(escrows).save(argThat(e -> !e.isFundsHeld()));
        verifyNoInteractions(listenerWallets, wallets, transactions);
    }

    @Test
    void retryWithSameIdempotencyKeyDoesNotHoldMoneyTwice() {
        AppUser listener = user("LISTENER");
        AppUser creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setProducerProfileId(UUID.randomUUID());
        profile.setUser(creator);
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setUser(listener);
        request.setProducerProfile(profile);
        request.setRequestedTitle("Audio lịch sử");
        request.setDescription("Mô tả");
        request.setStatus("PENDING");
        ContractEscrow existing = new ContractEscrow();
        existing.setRequest(request);
        existing.setBudget(new BigDecimal("100000"));
        existing.setRemaining(new BigDecimal("100000"));
        existing.setFundsHeld(false);
        existing.setProductType("AUDIO");
        existing.setFileFormat("MP3");
        existing.setDurationDescription("10 phút");
        existing.setAcceptanceCriteria("Âm thanh rõ");
        UUID key = UUID.randomUUID();
        when(users.findByIdForUpdate(listener.getUserId())).thenReturn(Optional.of(listener));
        when(escrows.findByIdempotencyKey(key)).thenReturn(Optional.of(existing));

        var result = service.create(listener.getUserId(), new ContractWorkflowRequests.Create(
                key, profile.getProducerProfileId(), "Audio lịch sử", "Mô tả",
                new BigDecimal("100000"), "AUDIO", "MP3", "10 phút", "Âm thanh rõ", false));

        assertEquals(request.getSeriesRequestId(), result.requestId());
        assertEquals(0, result.heldAmount().compareTo(BigDecimal.ZERO));
        verify(listenerWallets, never()).walletForLockedUser(any());
        verify(transactions, never()).save(any());
    }

    @Test
    void unapprovedCreatorCannotReceiveFundedRequest() {
        AppUser listener = user("LISTENER");
        ProducerProfile profile = new ProducerProfile();
        profile.setProducerProfileId(UUID.randomUUID());
        profile.setUser(user("CREATOR"));
        profile.setVerificationStatus("PENDING");
        when(users.findByIdForUpdate(listener.getUserId())).thenReturn(Optional.of(listener));
        when(creators.findById(profile.getProducerProfileId())).thenReturn(Optional.of(profile));

        assertThrows(PodcastWorkflowException.class, () -> service.create(listener.getUserId(),
                new ContractWorkflowRequests.Create(UUID.randomUUID(), profile.getProducerProfileId(),
                        "Audio lịch sử", "Mô tả", new BigDecimal("100000"),
                        "AUDIO", "MP3", "10 phút", "Âm thanh rõ", false)));

        verify(listenerWallets, never()).walletForLockedUser(any());
        verify(requests, never()).saveAndFlush(any());
    }

    @Test
    void creatorCanReadRequirementsBeforeMakingProposal() {
        AppUser listener = user("LISTENER");
        listener.setDisplayName("Người đặt hàng");
        listener.setAvatarUrl("https://example.test/listener.png");
        AppUser creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setProducerProfileId(UUID.randomUUID());
        profile.setUser(creator);
        profile.setChannelName("Kênh lịch sử");
        profile.setAvatarUrl("https://example.test/channel.png");
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setUser(listener);
        request.setProducerProfile(profile);
        request.setRequestedTitle("Audio lịch sử");
        request.setDescription("Mô tả đầy đủ");
        request.setStatus("PENDING");
        ContractEscrow escrow = new ContractEscrow();
        escrow.setRequest(request);
        escrow.setBudget(new BigDecimal("100000"));
        escrow.setRemaining(new BigDecimal("100000"));
        escrow.setFundsHeld(false);
        escrow.setProductType("AUDIO");
        escrow.setFileFormat("MP3");
        escrow.setDurationDescription("10 phút");
        escrow.setAcceptanceCriteria("Âm thanh rõ");
        when(escrows.findByRequest_SeriesRequestId(request.getSeriesRequestId()))
                .thenReturn(Optional.of(escrow));
        when(users.findById(creator.getUserId())).thenReturn(Optional.of(creator));

        var detail = service.getRequestDetail(creator.getUserId(), request.getSeriesRequestId());

        assertEquals("AUDIO", detail.productType());
        assertEquals("MP3", detail.fileFormat());
        assertEquals("Âm thanh rõ", detail.acceptanceCriteria());
        assertEquals(0, detail.remainingHeld().compareTo(BigDecimal.ZERO));
        assertFalse(detail.fundsHeld());
        assertEquals(listener.getUserId(), detail.listenerId());
        assertEquals("Người đặt hàng", detail.listenerName());
        assertEquals("Kênh lịch sử", detail.creatorChannelName());
        assertEquals("https://example.test/channel.png", detail.creatorAvatarUrl());
    }

    @Test
    void unrelatedUserCannotReadFundedRequestDetails() {
        AppUser listener = user("LISTENER");
        AppUser creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setUser(listener);
        request.setProducerProfile(profile);
        ContractEscrow escrow = new ContractEscrow();
        escrow.setRequest(request);
        when(escrows.findByRequest_SeriesRequestId(request.getSeriesRequestId()))
                .thenReturn(Optional.of(escrow));

        assertThrows(PodcastWorkflowException.class, () -> service.getRequestDetail(
                UUID.randomUUID(), request.getSeriesRequestId()));
        verify(users, never()).findById(any());
    }

    @Test
    void creatorCanFindContractRequestAfterItLeavesIncomingInbox() {
        AppUser creator = user("CREATOR");
        AppUser listener = user("LISTENER");
        ProducerProfile profile = new ProducerProfile();
        profile.setProducerProfileId(UUID.randomUUID());
        profile.setUser(creator);
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setUser(listener);
        request.setProducerProfile(profile);
        request.setStatus("ACCEPTED");
        request.setRequestedTitle("Audio lịch sử");
        request.setDescription("Mô tả");
        ContractEscrow escrow = new ContractEscrow();
        escrow.setRequest(request);
        escrow.setBudget(new BigDecimal("100000"));
        escrow.setRemaining(new BigDecimal("100000"));
        escrow.setFundsHeld(false);
        escrow.setProductType("AUDIO");
        escrow.setFileFormat("MP3");
        escrow.setDurationDescription("10 phút");
        escrow.setAcceptanceCriteria("Âm thanh rõ");
        when(users.findById(creator.getUserId())).thenReturn(Optional.of(creator));
        when(escrows.findAllForCreator(creator.getUserId())).thenReturn(List.of(escrow));

        var found = service.getCreatorContractRequests(creator.getUserId());

        assertEquals(1, found.size());
        assertEquals(request.getSeriesRequestId(), found.get(0).requestId());
        assertEquals("ACCEPTED", found.get(0).status());
    }

    @Test
    void approvedStagePaysCreatorNetAndRecordsPlatformFeeOnce() {
        AppUser listener = user("LISTENER");
        AppUser creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setUser(listener);
        contract.setProducerProfile(profile);
        contract.setStatus("IN_PROGRESS");
        ContractStage stage = new ContractStage();
        stage.setContractStageId(UUID.randomUUID());
        stage.setContract(contract);
        stage.setStatus(ContractStageStatus.SUBMITTED.name());
        stage.setAmount(new BigDecimal("20000"));
        SeriesRequest request = new SeriesRequest();
        request.setUser(listener);
        ContractEscrow escrow = new ContractEscrow();
        escrow.setRequest(request);
        escrow.setContract(contract);
        escrow.setRemaining(new BigDecimal("100000"));
        escrow.setListenerSignedAt(Instant.now());
        escrow.setCreatorSignedAt(Instant.now());
        UserWallet listenerWallet = wallet(listener, "0", "100000");
        UserWallet creatorWallet = wallet(creator, "0", "0");
        when(escrows.lockByContractId(contract.getContractId())).thenReturn(Optional.of(escrow));
        when(payments.findFirstByContractStage_ContractStageId(stage.getContractStageId()))
                .thenReturn(Optional.empty());
        when(users.findByIdForUpdate(listener.getUserId())).thenReturn(Optional.of(listener));
        when(users.findByIdForUpdate(creator.getUserId())).thenReturn(Optional.of(creator));
        when(listenerWallets.walletForLockedUser(listener)).thenReturn(listenerWallet);
        when(wallets.findByUserIdForUpdate(creator.getUserId())).thenReturn(Optional.of(creatorWallet));
        when(payments.saveAndFlush(any(Payment.class))).thenAnswer(call -> {
            Payment payment = call.getArgument(0);
            payment.setPaymentId(UUID.randomUUID());
            return payment;
        });

        var result = service.settle(stage);

        assertEquals(0, result.creatorNet().compareTo(new BigDecimal("16000")));
        assertEquals(0, result.platformFee().compareTo(new BigDecimal("4000")));
        assertEquals(0, listenerWallet.getHeldBalance().compareTo(new BigDecimal("80000")));
        assertEquals(0, creatorWallet.getBalance().compareTo(new BigDecimal("16000")));
        assertEquals(0, escrow.getRemaining().compareTo(new BigDecimal("80000")));
        verify(transactions).save(argThat(t -> "PLATFORM_FEE".equals(t.getTransactionType())
                && t.getAmount().compareTo(new BigDecimal("4000")) == 0));
        verify(transactions).save(argThat(t -> "RELEASE_FUNDS".equals(t.getTransactionType())
                && t.getAmount().compareTo(new BigDecimal("16000")) == 0));
    }

    @Test
    void settlementDoesNotSpendOtherContractsHeldBalance() {
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setStatus("IN_PROGRESS");
        ContractStage stage = new ContractStage();
        stage.setContractStageId(UUID.randomUUID());
        stage.setContract(contract);
        stage.setStatus("SUBMITTED");
        stage.setAmount(new BigDecimal("20000"));
        ContractEscrow escrow = new ContractEscrow();
        escrow.setRemaining(new BigDecimal("10000"));
        escrow.setListenerSignedAt(Instant.now());
        escrow.setCreatorSignedAt(Instant.now());
        when(escrows.lockByContractId(contract.getContractId())).thenReturn(Optional.of(escrow));
        when(payments.findFirstByContractStage_ContractStageId(stage.getContractStageId()))
                .thenReturn(Optional.empty());

        assertThrows(PodcastWorkflowException.class, () -> service.settle(stage));
        verify(payments, never()).save(any());
    }

    @Test
    void bothPartiesSignSameHashBeforeContractBecomesActive() {
        AppUser listener = user("LISTENER");
        AppUser creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setUser(listener);
        request.setProducerProfile(profile);
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setUser(listener);
        contract.setStatus("PENDING_SIGNATURE");
        ContractEscrow escrow = new ContractEscrow();
        escrow.setRequest(request);
        escrow.setContract(contract);
        escrow.setContractVersion(1);
        escrow.setContentHash("abc123");
        escrow.setContentSnapshot("Bản hợp đồng cố định");
        escrow.setBudget(new BigDecimal("100000"));
        escrow.setRemaining(new BigDecimal("100000"));
        when(requests.findByIdForUpdate(request.getSeriesRequestId())).thenReturn(Optional.of(request));
        when(escrows.lockByRequestId(request.getSeriesRequestId())).thenReturn(Optional.of(escrow));
        when(users.findById(creator.getUserId())).thenReturn(Optional.of(creator));
        when(users.findById(listener.getUserId())).thenReturn(Optional.of(listener));
        when(users.findByIdForUpdate(listener.getUserId())).thenReturn(Optional.of(listener));
        when(listenerWallets.walletForLockedUser(listener)).thenReturn(wallet(listener, "0", "100000"));

        service.sign(creator.getUserId(), request.getSeriesRequestId(),
                new ContractWorkflowRequests.Sign(1, "abc123", true));
        assertEquals("PENDING_SIGNATURE", contract.getStatus());
        assertNotNull(escrow.getCreatorSignedAt());
        assertNull(escrow.getListenerSignedAt());

        service.sign(listener.getUserId(), request.getSeriesRequestId(),
                new ContractWorkflowRequests.Sign(1, "abc123", true));
        assertEquals("IN_PROGRESS", contract.getStatus());
        assertNotNull(escrow.getListenerSignedAt());
        assertEquals("abc123", escrow.getContentHash());
    }

    @Test
    void proposalRejectsMilestonesThatDoNotMatchHeldBudget() {
        AppUser creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setProducerProfile(profile);
        request.setStatus("PENDING");
        ContractEscrow escrow = new ContractEscrow();
        escrow.setBudget(new BigDecimal("100000"));
        when(users.findByIdForUpdate(creator.getUserId())).thenReturn(Optional.of(creator));
        when(requests.findByIdForUpdate(request.getSeriesRequestId())).thenReturn(Optional.of(request));
        when(escrows.lockByRequestId(request.getSeriesRequestId())).thenReturn(Optional.of(escrow));

        var input = new ContractWorkflowRequests.Proposal("Làm được", List.of(
                new ContractWorkflowRequests.Stage("Đợt 1", "Bản nháp", Instant.now().plusSeconds(86400),
                        new BigDecimal("90000"))));
        assertThrows(PodcastWorkflowException.class,
                () -> service.propose(creator.getUserId(), request.getSeriesRequestId(), input));
        verify(contracts, never()).saveAndFlush(any());
    }

    @Test
    void proposalWithInsufficientListenerBalanceDoesNotCreateContractOrHold() {
        AppUser listener = user("LISTENER");
        AppUser creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setUser(listener);
        request.setProducerProfile(profile);
        request.setStatus("PENDING");
        ContractEscrow escrow = new ContractEscrow();
        escrow.setRequest(request);
        escrow.setBudget(new BigDecimal("100000"));
        escrow.setRemaining(new BigDecimal("100000"));
        escrow.setFundsHeld(false);
        UserWallet wallet = wallet(listener, "90000", "0");
        when(users.findByIdForUpdate(creator.getUserId())).thenReturn(Optional.of(creator));
        when(requests.findByIdForUpdate(request.getSeriesRequestId())).thenReturn(Optional.of(request));
        when(escrows.lockByRequestId(request.getSeriesRequestId())).thenReturn(Optional.of(escrow));
        when(users.findByIdForUpdate(listener.getUserId())).thenReturn(Optional.of(listener));
        when(listenerWallets.walletForLockedUser(listener)).thenReturn(wallet);

        var input = new ContractWorkflowRequests.Proposal("Tôi nhận làm", List.of(
                new ContractWorkflowRequests.Stage("Đợt 1", "Bản audio",
                        Instant.now().plusSeconds(86400), new BigDecimal("100000"))));
        assertThrows(PodcastWorkflowException.class,
                () -> service.propose(creator.getUserId(), request.getSeriesRequestId(), input));

        assertEquals("PENDING", request.getStatus());
        assertFalse(escrow.isFundsHeld());
        assertEquals(0, wallet.getBalance().compareTo(new BigDecimal("90000")));
        verifyNoInteractions(wallets, transactions, contracts, responses, stages);
    }

    @Test
    void cancelBeforeProposalDoesNotTouchWallet() {
        AppUser listener = user("LISTENER");
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setUser(listener);
        ProducerProfile profile = new ProducerProfile();
        profile.setProducerProfileId(UUID.randomUUID());
        request.setProducerProfile(profile);
        request.setStatus("PENDING");
        ContractEscrow escrow = new ContractEscrow();
        escrow.setRequest(request);
        escrow.setBudget(new BigDecimal("100000"));
        escrow.setRemaining(new BigDecimal("100000"));
        escrow.setFundsHeld(false);
        when(requests.findByIdForUpdate(request.getSeriesRequestId())).thenReturn(Optional.of(request));
        when(escrows.lockByRequestId(request.getSeriesRequestId())).thenReturn(Optional.of(escrow));

        var result = service.cancel(listener.getUserId(), request.getSeriesRequestId());

        assertEquals("CANCELLED", result.status());
        assertEquals(0, escrow.getRemaining().compareTo(BigDecimal.ZERO));
        verifyNoInteractions(users, listenerWallets, wallets, transactions);
    }

    @Test
    void creatorCanChooseFourStagesAndAllAppearInSignedSnapshot() {
        AppUser listener = user("LISTENER");
        AppUser creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        profile.setChannelName("Kênh lịch sử");
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setUser(listener);
        request.setProducerProfile(profile);
        request.setRequestedTitle("Audio lịch sử");
        request.setDescription("Mô tả");
        request.setStatus("PENDING");
        ContractEscrow escrow = new ContractEscrow();
        escrow.setRequest(request);
        escrow.setBudget(new BigDecimal("100000"));
        escrow.setRemaining(new BigDecimal("100000"));
        escrow.setFundsHeld(false);
        escrow.setProductType("AUDIO");
        escrow.setFileFormat("MP3");
        escrow.setDurationDescription("10 phút");
        escrow.setAcceptanceCriteria("Âm thanh rõ");
        List<ContractStage> persistedStages = new ArrayList<>();
        when(users.findByIdForUpdate(creator.getUserId())).thenReturn(Optional.of(creator));
        when(requests.findByIdForUpdate(request.getSeriesRequestId())).thenReturn(Optional.of(request));
        when(escrows.lockByRequestId(request.getSeriesRequestId())).thenReturn(Optional.of(escrow));
        UserWallet wallet = wallet(listener, "150000", "0");
        when(users.findByIdForUpdate(listener.getUserId())).thenReturn(Optional.of(listener));
        when(listenerWallets.walletForLockedUser(listener)).thenReturn(wallet);
        when(responses.save(any(RequestResponse.class))).thenAnswer(call -> call.getArgument(0));
        when(contracts.saveAndFlush(any(Contract.class))).thenAnswer(call -> {
            Contract contract = call.getArgument(0);
            contract.setContractId(UUID.randomUUID());
            contract.setCreatedAt(Instant.now());
            return contract;
        });
        when(stages.save(any(ContractStage.class))).thenAnswer(call -> {
            ContractStage stage = call.getArgument(0);
            stage.setContractStageId(UUID.randomUUID());
            persistedStages.add(stage);
            return stage;
        });
        when(stages.findAllByContract_ContractIdOrderByStageOrder(any()))
                .thenAnswer(call -> persistedStages);
        Instant firstDue = Instant.now().plusSeconds(86400);
        var offers = List.of(
                new ContractWorkflowRequests.Stage("Dàn ý", "Dàn ý", firstDue, new BigDecimal("10000")),
                new ContractWorkflowRequests.Stage("Bản nháp", "Bản nháp", firstDue.plusSeconds(86400), new BigDecimal("20000")),
                new ContractWorkflowRequests.Stage("Bản sửa", "Bản sửa", firstDue.plusSeconds(172800), new BigDecimal("30000")),
                new ContractWorkflowRequests.Stage("Bản hoàn chỉnh", "Bản hoàn chỉnh", firstDue.plusSeconds(259200), new BigDecimal("40000")));

        var agreement = service.propose(creator.getUserId(), request.getSeriesRequestId(),
                new ContractWorkflowRequests.Proposal("Tôi nhận làm", offers));

        assertEquals(4, agreement.milestones().size());
        assertEquals(6, agreement.contractVersion());
        assertTrue(escrow.isFundsHeld());
        assertEquals(0, wallet.getBalance().compareTo(new BigDecimal("50000")));
        assertEquals(0, wallet.getHeldBalance().compareTo(new BigDecimal("100000")));
        verify(transactions, times(1)).save(argThat(t -> "CONTRACT_HOLD".equals(t.getTransactionType())));
        assertTrue(agreement.contentSnapshot().contains("Hợp đồng có 4 đợt"));
        assertTrue(agreement.contentSnapshot().contains("| 4 | Bản hoàn chỉnh | Bản hoàn chỉnh |"));
        assertTrue(agreement.contentSnapshot().contains("tạm giữ toàn bộ ngân sách từ ví Bên A"));
        assertFalse(agreement.contentSnapshot().contains("AI chỉ đánh giá hình ảnh"));
        assertTrue(agreement.contentSnapshot().contains("AI không đánh giá hình ảnh"));
        assertTrue(agreement.contentSnapshot().contains("CC nhận 80%, nền tảng ghi nhận phí 20%"));
        assertTrue(agreement.contentSnapshot().contains("Listener thắng, toàn bộ số tiền còn giữ"));
        assertTrue(agreement.contentSnapshot().contains("CC thắng, toàn bộ số tiền còn giữ"));
        assertFalse(agreement.contentSnapshot().contains("khoản đền công có thể bằng 30%"));
        assertFalse(agreement.contentSnapshot().contains("[MILESTONE_ROWS]"));
        assertEquals(64, agreement.contentHash().length());
        assertEquals("PENDING_SIGNATURE", agreement.contractStatus());
    }

    @Test
    void staffTerminationTakesTenPercentFeeFromCreatorCompensationAndRefundsRemainder() {
        AppUser admin = user("STAFF");
        AppUser listener = user("LISTENER");
        AppUser creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setUser(listener);
        contract.setProducerProfile(profile);
        contract.setStatus("DISPUTED");
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setUser(listener);
        ContractEscrow escrow = new ContractEscrow();
        escrow.setRequest(request);
        escrow.setContract(contract);
        escrow.setBudget(new BigDecimal("100000"));
        escrow.setRemaining(new BigDecimal("100000"));
        ContractStage stage = new ContractStage();
        stage.setContractStageId(UUID.randomUUID());
        stage.setContract(contract);
        stage.setStageOrder(1);
        stage.setStatus("SUBMITTED");
        stage.setAmount(new BigDecimal("40000"));
        MilestoneSubmission submission = new MilestoneSubmission();
        submission.setMilestoneSubmissionId(UUID.randomUUID());
        submission.setContractStage(stage);
        ContractDispute dispute = new ContractDispute();
        dispute.setContract(contract);
        dispute.setCreatedAt(Instant.now().minusSeconds(4 * 86400L));
        dispute.setStatus("OPEN");
        UserWallet listenerWallet = wallet(listener, "0", "100000");
        UserWallet creatorWallet = wallet(creator, "0", "0");
        when(users.findByIdForUpdate(admin.getUserId())).thenReturn(Optional.of(admin));
        when(users.findByIdForUpdate(listener.getUserId())).thenReturn(Optional.of(listener));
        when(users.findByIdForUpdate(creator.getUserId())).thenReturn(Optional.of(creator));
        when(contracts.lockById(contract.getContractId())).thenReturn(Optional.of(contract));
        when(contractDisputes.findFirstByContract_ContractIdAndStatus(contract.getContractId(), "OPEN"))
                .thenReturn(Optional.of(dispute));
        when(contractDisputes.lockById(dispute.getDisputeId())).thenReturn(Optional.of(dispute));
        when(stages.lockAllByContractId(contract.getContractId())).thenReturn(List.of(stage));
        when(escrows.lockByContractId(contract.getContractId())).thenReturn(Optional.of(escrow));
        when(submissions.findById(submission.getMilestoneSubmissionId())).thenReturn(Optional.of(submission));
        when(payments.findFirstByContractStage_ContractStageId(stage.getContractStageId()))
                .thenReturn(Optional.empty());
        when(listenerWallets.walletForLockedUser(listener)).thenReturn(listenerWallet);
        when(wallets.findByUserIdForUpdate(creator.getUserId())).thenReturn(Optional.of(creatorWallet));
        when(payments.saveAndFlush(any(Payment.class))).thenAnswer(call -> {
            Payment payment = call.getArgument(0);
            payment.setPaymentId(UUID.randomUUID());
            return payment;
        });

        var result = service.terminate(admin.getUserId(), contract.getContractId(),
                new ContractWorkflowRequests.Terminate("Đã đối chiếu", true,
                        submission.getMilestoneSubmissionId(), "Đáp ứng tiêu chí âm thanh tối thiểu"));

        assertEquals(0, result.compensationGross().compareTo(new BigDecimal("12000")));
        assertEquals(0, result.platformFee().compareTo(new BigDecimal("1200")));
        assertEquals(0, result.creatorNet().compareTo(new BigDecimal("10800")));
        assertEquals(0, result.refundedToListener().compareTo(new BigDecimal("88000")));
        assertEquals(0, listenerWallet.getBalance().compareTo(new BigDecimal("88000")));
        assertEquals(0, listenerWallet.getHeldBalance().compareTo(BigDecimal.ZERO));
        assertEquals(0, creatorWallet.getBalance().compareTo(new BigDecimal("10800")));
        assertEquals("TERMINATED", contract.getStatus());
        assertEquals(admin.getUserId(), dispute.getReviewer().getUserId());
    }

    @Test
    void listenerCanCancelAfterOwnSignatureWhileCreatorHasNotSigned() {
        AppUser listener = user("LISTENER");
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setUser(listener);
        ProducerProfile profile = new ProducerProfile();
        profile.setProducerProfileId(UUID.randomUUID());
        request.setProducerProfile(profile);
        request.setStatus("ACCEPTED");
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setStatus("PENDING_SIGNATURE");
        ContractStage stage = new ContractStage();
        stage.setStatus("NOT_STARTED");
        ContractEscrow escrow = new ContractEscrow();
        escrow.setRequest(request);
        escrow.setContract(contract);
        escrow.setBudget(new BigDecimal("100000"));
        escrow.setRemaining(new BigDecimal("100000"));
        escrow.setListenerSignedAt(Instant.now());
        UserWallet wallet = wallet(listener, "0", "100000");
        when(requests.findByIdForUpdate(request.getSeriesRequestId())).thenReturn(Optional.of(request));
        when(escrows.lockByRequestId(request.getSeriesRequestId())).thenReturn(Optional.of(escrow));
        when(users.findByIdForUpdate(listener.getUserId())).thenReturn(Optional.of(listener));
        when(listenerWallets.walletForLockedUser(listener)).thenReturn(wallet);
        when(stages.findAllByContract_ContractIdOrderByStageOrder(contract.getContractId()))
                .thenReturn(List.of(stage));

        var result = service.cancel(listener.getUserId(), request.getSeriesRequestId());

        assertEquals("CANCELLED", result.status());
        assertEquals("CANCELLED", contract.getStatus());
        assertEquals("CANCELLED", stage.getStatus());
        assertEquals(0, wallet.getBalance().compareTo(new BigDecimal("100000")));
        assertEquals(0, wallet.getHeldBalance().compareTo(BigDecimal.ZERO));
        assertEquals(0, escrow.getRemaining().compareTo(BigDecimal.ZERO));
        verify(transactions).save(argThat(t -> "CONTRACT_REFUND".equals(t.getTransactionType())));
    }

    @Test
    void terminationCannotDistributeEscrowBeforeNegotiationWindowEnds() {
        AppUser admin = user("ADMIN");
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setStatus("DISPUTED");
        ContractDispute dispute = new ContractDispute();
        dispute.setCreatedAt(Instant.now().minusSeconds(86400));
        dispute.setStatus("OPEN");
        when(users.findByIdForUpdate(admin.getUserId())).thenReturn(Optional.of(admin));
        when(contracts.lockById(contract.getContractId())).thenReturn(Optional.of(contract));
        when(contractDisputes.findFirstByContract_ContractIdAndStatus(contract.getContractId(), "OPEN"))
                .thenReturn(Optional.of(dispute));
        when(contractDisputes.lockById(dispute.getDisputeId())).thenReturn(Optional.of(dispute));

        assertThrows(PodcastWorkflowException.class, () -> service.terminate(admin.getUserId(),
                contract.getContractId(), new ContractWorkflowRequests.Terminate("Chấm dứt", false, null, null)));
        verify(payments, never()).save(any());
        verify(wallets, never()).save(any());
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

    private UserWallet wallet(AppUser user, String balance, String held) {
        UserWallet wallet = new UserWallet();
        wallet.setUser(user);
        wallet.setBalance(new BigDecimal(balance));
        wallet.setHeldBalance(new BigDecimal(held));
        wallet.setCurrency("VND");
        wallet.setStatus("ACTIVE");
        return wallet;
    }
}
