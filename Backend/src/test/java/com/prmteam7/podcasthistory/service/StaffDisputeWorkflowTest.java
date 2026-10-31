package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.prmteam7.podcasthistory.dto.request.ResolveDisputeRequest;
import com.prmteam7.podcasthistory.dto.response.DisputeResponse;
import com.prmteam7.podcasthistory.enums.MilestoneDisputeDecision;
import com.prmteam7.podcasthistory.enums.ListenerWinAction;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.exception.PodcastWorkflowException;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
class StaffDisputeWorkflowTest {
    @Mock AppUserRepository users;
    @Mock ContractRepository contracts;
    @Mock ContractStageRepository stages;
    @Mock MilestoneDisputeRepository disputes;
    @Mock MilestoneRevisionRepository revisions;
    @Mock MilestoneSubmissionRepository submissions;
    @Mock ContractEscrowService escrows;
    @Mock DisputeStaffNotifier notifier;
    @Mock AdminSupportService support;
    @Mock ContractDisputeRepository contractDisputes;
    @Mock ContractEscrowRepository contractEscrows;
    @InjectMocks PodcastRequestService service;

    @Test
    void staffCanSeeOpenMilestoneDisputes() {
        AppUser staff = user("STAFF");
        MilestoneDispute dispute = dispute();
        when(users.findById(staff.getUserId())).thenReturn(Optional.of(staff));
        when(disputes.findAllByStatusOrderByCreatedAtAsc("OPEN")).thenReturn(List.of(dispute));

        var result = service.getOpenDisputes(staff.getUserId());

        assertEquals(1, result.size());
        assertEquals(dispute.getMilestoneDisputeId(), result.get(0).disputeId());
        assertEquals("Đợt bàn giao", result.get(0).milestoneName());
        assertEquals("Kênh lịch sử", result.get(0).creatorChannelName());
    }

    @Test
    void staffCanResolveMilestoneDisputeByRequestingRevision() {
        AppUser staff = user("STAFF");
        MilestoneDispute dispute = dispute();
        UUID disputeId = dispute.getMilestoneDisputeId();
        ContractStage stage = dispute.getContractStage();
        when(users.findById(staff.getUserId())).thenReturn(Optional.of(staff));
        when(disputes.findContractIdByDisputeId(disputeId))
                .thenReturn(Optional.of(stage.getContract().getContractId()));
        when(contracts.lockById(stage.getContract().getContractId()))
                .thenReturn(Optional.of(stage.getContract()));
        when(disputes.findByIdForUpdate(disputeId)).thenReturn(Optional.of(dispute));
        when(disputes.findById(disputeId)).thenReturn(Optional.of(dispute));
        when(stages.findById(stage.getContractStageId())).thenReturn(Optional.of(stage));
        when(stages.findByIdForUpdate(stage.getContractStageId())).thenReturn(Optional.of(stage));
        when(disputes.save(any(MilestoneDispute.class))).thenAnswer(call -> call.getArgument(0));

        var result = service.resolveDispute(staff.getUserId(), disputeId,
                new ResolveDisputeRequest(MilestoneDisputeDecision.REQUEST_REVISION, "Cần sửa âm thanh"));

        assertEquals("RESOLVED", result.status());
        assertEquals("REVISION_REQUESTED", stage.getStatus());
        assertEquals(staff.getUserId(), result.reviewedByUserId());
        verify(revisions).save(any(MilestoneRevision.class));
    }

    @Test
    void newlyOpenedDisputeNotifiesStaff() {
        AppUser creator = user("CREATOR");
        AppUser listener = user("LISTENER");
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setUser(listener);
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        contract.setProducerProfile(profile);
        ContractStage stage = new ContractStage();
        stage.setContractStageId(UUID.randomUUID());
        stage.setContract(contract);
        stage.setStatus("SUBMITTED");
        when(users.findById(listener.getUserId())).thenReturn(Optional.of(listener));
        when(stages.findById(stage.getContractStageId())).thenReturn(Optional.of(stage));
        when(contracts.lockById(contract.getContractId())).thenReturn(Optional.of(contract));
        when(stages.findByIdForUpdate(stage.getContractStageId())).thenReturn(Optional.of(stage));
        when(disputes.save(any(MilestoneDispute.class))).thenAnswer(call -> {
            MilestoneDispute saved = call.getArgument(0);
            saved.setMilestoneDisputeId(UUID.randomUUID());
            return saved;
        });

        var result = service.raiseDispute(listener.getUserId(), stage.getContractStageId(), "Cần xử lý");

        assertEquals("OPEN", result.status());
        verify(notifier).notifyOpen("đợt", result.disputeId());
    }

    @Test
    void notifierSendsToEveryActiveStaffAccount() {
        AppUser first = user("STAFF");
        AppUser second = user("STAFF");
        when(users.findAllByRole_RoleCodeAndIsActiveTrue("STAFF"))
                .thenReturn(List.of(first, second));
        UUID id = UUID.randomUUID();

        new DisputeStaffNotifier(users, support).notifyOpen("hợp đồng", id);

        verify(support).notify(first, "DISPUTE_ASSIGNED", "Tranh chấp cần xử lý",
                "Có tranh chấp hợp đồng mới: " + id);
        verify(support).notify(second, "DISPUTE_ASSIGNED", "Tranh chấp cần xử lý",
                "Có tranh chấp hợp đồng mới: " + id);
    }

    @Test
    void staffAndAdminCanUseContractDisputeQueue() {
        UUID staffId = UUID.randomUUID();
        UUID adminId = UUID.randomUUID();
        when(contractDisputes.findAll(any(org.springframework.data.jpa.domain.Specification.class),
                any(org.springframework.data.domain.Pageable.class))).thenReturn(Page.empty());
        AdminDisputeService queue = new AdminDisputeService(support, contracts, stages,
                contractDisputes, null, contractEscrows, notifier, null);

        assertEquals(0, queue.disputes(staffId, "OPEN", 0, 20).getTotalElements());
        assertEquals(0, queue.disputes(adminId, "OPEN", 0, 20).getTotalElements());
        verify(support).actor(staffId, false);
        verify(support).actor(adminId, false);
    }

    @Test
    void staffAndAdminContractResponsesIncludeParticipantNamesAndRequestTitle() {
        AppUser staff = user("STAFF");
        AppUser admin = user("ADMIN");
        AppUser listener = user("LISTENER");
        listener.setDisplayName("Nguyễn Văn A");
        listener.setAvatarUrl("https://example.test/listener.png");
        AppUser creator = user("CREATOR");
        creator.setDisplayName("Trần Văn B");
        ProducerProfile profile = new ProducerProfile();
        profile.setProducerProfileId(UUID.randomUUID());
        profile.setUser(creator);
        profile.setChannelName("Kênh lịch sử");
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setRequestedTitle("Podcast lịch sử Việt Nam");
        RequestResponse response = new RequestResponse();
        response.setSeriesRequest(request);
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setUser(listener);
        contract.setProducerProfile(profile);
        contract.setSeriesResponse(response);
        contract.setStatus("DISPUTED");
        ContractDispute dispute = new ContractDispute();
        dispute.setContract(contract);
        dispute.setOpenedBy(listener);
        dispute.setStatus("OPEN");
        when(contracts.findAll(any(org.springframework.data.jpa.domain.Specification.class),
                any(org.springframework.data.domain.Pageable.class)))
                .thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(contract)));
        when(contractDisputes.findAll(any(org.springframework.data.jpa.domain.Specification.class),
                any(org.springframework.data.domain.Pageable.class)))
                .thenReturn(new org.springframework.data.domain.PageImpl<>(List.of(dispute)));
        AdminDisputeService queue = new AdminDisputeService(support, contracts, stages,
                contractDisputes, null, contractEscrows, notifier, escrows);

        var staffContract = queue.contracts(staff.getUserId(), "DISPUTED", 0, 20).getContent().get(0);
        var adminDispute = queue.disputes(admin.getUserId(), "OPEN", 0, 20).getContent().get(0);

        assertEquals("Nguyễn Văn A", staffContract.listenerName());
        assertEquals("Trần Văn B", staffContract.creatorName());
        assertEquals("Kênh lịch sử", staffContract.creatorChannelName());
        assertEquals("Podcast lịch sử Việt Nam", staffContract.requestTitle());
        assertEquals("Nguyễn Văn A", adminDispute.openedByName());
        assertEquals("Podcast lịch sử Việt Nam", adminDispute.requestTitle());
        verify(support).actor(staff.getUserId(), false);
        verify(support).actor(admin.getUserId(), false);
    }

    @Test
    void contractTerminationRequestNotifiesStaff() {
        AppUser listener = user("LISTENER");
        AppUser creator = user("CREATOR");
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setUser(listener);
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        contract.setProducerProfile(profile);
        contract.setStatus("IN_PROGRESS");
        when(support.user(listener.getUserId())).thenReturn(listener);
        when(contracts.lockById(contract.getContractId())).thenReturn(Optional.of(contract));
        when(contractDisputes.save(any(ContractDispute.class))).thenAnswer(call -> {
            ContractDispute saved = call.getArgument(0);
            ReflectionTestUtils.setField(saved, "disputeId", UUID.randomUUID());
            return saved;
        });
        AdminDisputeService queue = new AdminDisputeService(support, contracts, stages,
                contractDisputes, null, contractEscrows, notifier, null);

        var result = queue.open(listener.getUserId(), contract.getContractId(), "Muốn chấm dứt");

        assertEquals("OPEN", result.status());
        assertEquals("DISPUTED", contract.getStatus());
        verify(notifier).notifyOpen("hợp đồng", result.disputeId());
    }

    @Test
    void openerCanWithdrawPendingContractDisputeOnlyOnce() {
        AppUser listener = user("LISTENER");
        AppUser creator = user("CREATOR");
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setUser(listener);
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        contract.setProducerProfile(profile);
        contract.setStatus("DISPUTED");
        ContractDispute dispute = new ContractDispute();
        UUID disputeId = UUID.randomUUID();
        ReflectionTestUtils.setField(dispute, "disputeId", disputeId);
        ReflectionTestUtils.setField(dispute, "createdAt", Instant.now());
        dispute.setContract(contract);
        dispute.setOpenedBy(listener);
        dispute.setReason("Nhầm");
        dispute.setPreviousContractStatus("IN_PROGRESS");
        dispute.setStatus("AWAITING_RESPONSE");
        when(support.user(listener.getUserId())).thenReturn(listener);
        when(contractDisputes.findById(disputeId)).thenReturn(Optional.of(dispute));
        when(contracts.lockById(contract.getContractId())).thenReturn(Optional.of(contract));
        when(contractDisputes.lockById(disputeId)).thenReturn(Optional.of(dispute));
        AdminDisputeService queue = new AdminDisputeService(support, contracts, stages,
                contractDisputes, null, contractEscrows, notifier, escrows);

        assertEquals("WITHDRAWN", queue.withdraw(listener.getUserId(), disputeId).status());
        assertEquals("IN_PROGRESS", contract.getStatus());
        assertEquals("WITHDRAWN", queue.withdraw(listener.getUserId(), disputeId).status());
        verify(notifier).notifyWithdrawn(creator, "hợp đồng", disputeId);
        org.mockito.Mockito.verify(contractDisputes, org.mockito.Mockito.times(1)).save(dispute);
        org.mockito.Mockito.verify(escrows, org.mockito.Mockito.never()).resolveListenerWin(
                any(), any(), any());
    }

    @Test
    void openerCanWithdrawPendingMilestoneWithoutPayment() {
        AppUser listener = user("LISTENER");
        AppUser creator = user("CREATOR");
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setUser(listener);
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        contract.setProducerProfile(profile);
        contract.setStatus("IN_PROGRESS");
        ContractStage stage = new ContractStage();
        stage.setContractStageId(UUID.randomUUID());
        stage.setContract(contract);
        stage.setStatus("DISPUTED");
        MilestoneDispute dispute = new MilestoneDispute();
        dispute.setMilestoneDisputeId(UUID.randomUUID());
        dispute.setContractStage(stage);
        dispute.setRaisedBy(listener);
        dispute.setStatus("AWAITING_RESPONSE");
        dispute.setPreviousStageStatus("SUBMITTED");
        ReflectionTestUtils.setField(dispute, "createdAt", Instant.now());
        when(users.findById(listener.getUserId())).thenReturn(Optional.of(listener));
        when(stages.findById(stage.getContractStageId())).thenReturn(Optional.of(stage));
        when(contracts.lockById(contract.getContractId())).thenReturn(Optional.of(contract));
        when(stages.findByIdForUpdate(stage.getContractStageId())).thenReturn(Optional.of(stage));
        when(disputes.findByIdForUpdate(dispute.getMilestoneDisputeId()))
                .thenReturn(Optional.of(dispute));

        DisputeResponse result = service.withdrawMilestoneDispute(listener.getUserId(),
                stage.getContractStageId(), dispute.getMilestoneDisputeId());

        assertEquals("WITHDRAWN", result.status());
        assertEquals("SUBMITTED", stage.getStatus());
        verify(notifier).notifyWithdrawn(creator, "đợt", dispute.getMilestoneDisputeId());
        org.mockito.Mockito.verify(escrows, org.mockito.Mockito.never()).settle(any());
        assertEquals("WITHDRAWN", service.withdrawMilestoneDispute(listener.getUserId(),
                stage.getContractStageId(), dispute.getMilestoneDisputeId()).status());
        org.mockito.Mockito.verify(disputes, org.mockito.Mockito.times(1)).save(dispute);

        dispute.setStatus("OPEN");
        stage.setStatus("DISPUTED");
        assertThrows(PodcastWorkflowException.class, () -> service.withdrawMilestoneDispute(
                listener.getUserId(), stage.getContractStageId(), dispute.getMilestoneDisputeId()));
    }

    @Test
    void escrowDisputeWaitsForCounterpartyAndAutoAwardsOpenerAfterThreeDays() {
        AppUser listener = user("LISTENER");
        AppUser creator = user("CREATOR");
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setUser(listener);
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        contract.setProducerProfile(profile);
        contract.setStatus("IN_PROGRESS");
        ContractEscrow escrow = new ContractEscrow();
        escrow.setContract(contract);
        when(support.user(listener.getUserId())).thenReturn(listener);
        when(contracts.lockById(contract.getContractId())).thenReturn(Optional.of(contract));
        when(contractEscrows.findByContract_ContractId(contract.getContractId()))
                .thenReturn(Optional.of(escrow));
        when(contractDisputes.save(any(ContractDispute.class))).thenAnswer(call -> {
            ContractDispute saved = call.getArgument(0);
            ReflectionTestUtils.setField(saved, "disputeId", UUID.randomUUID());
            ReflectionTestUtils.setField(saved, "createdAt", Instant.now().minus(4, ChronoUnit.DAYS));
            return saved;
        });
        AdminDisputeService queue = new AdminDisputeService(support, contracts, stages,
                contractDisputes, null, contractEscrows, notifier, escrows);

        var opened = queue.open(listener.getUserId(), contract.getContractId(), "Sản phẩm không đạt",
                ListenerWinAction.REFUND_STAGE_CONTINUE);

        assertEquals("AWAITING_RESPONSE", opened.status());
        verify(notifier).notifyCounterparty(creator, "hợp đồng", opened.disputeId());
        org.mockito.Mockito.verify(notifier, org.mockito.Mockito.never())
                .notifyOpen("hợp đồng", opened.disputeId());

        ContractDispute dispute = new ContractDispute();
        ReflectionTestUtils.setField(dispute, "disputeId", opened.disputeId());
        dispute.setContract(contract);
        dispute.setOpenedBy(listener);
        dispute.setReason("Sản phẩm không đạt");
        dispute.setPreviousContractStatus("IN_PROGRESS");
        dispute.setStatus("AWAITING_RESPONSE");
        dispute.setListenerWinAction(ListenerWinAction.REFUND_STAGE_CONTINUE);
        ReflectionTestUtils.setField(dispute, "createdAt", Instant.now().minus(4, ChronoUnit.DAYS));
        when(contractDisputes.findById(opened.disputeId())).thenReturn(Optional.of(dispute));
        when(contractDisputes.lockById(opened.disputeId())).thenReturn(Optional.of(dispute));

        assertThrows(ResourceConflictException.class,
                () -> queue.confirm(creator.getUserId(), opened.disputeId(), null));
        var resolved = queue.resolveTimeout(opened.disputeId());
        assertEquals("RESOLVED", resolved.status());
        assertEquals("LISTENER_WINS", resolved.decision());
        verify(escrows).resolveListenerWin(contract.getContractId(),
                ListenerWinAction.CANCEL_CONTRACT, null);
        assertEquals("RESOLVED", queue.resolveTimeout(opened.disputeId()).status());
        org.mockito.Mockito.verify(escrows, org.mockito.Mockito.times(1)).resolveListenerWin(
                contract.getContractId(), ListenerWinAction.CANCEL_CONTRACT, null);
    }

    @Test
    void creatorWinByTimeoutSettlesRemainingEscrowAndTerminates() {
        AppUser listener = user("LISTENER");
        AppUser creator = user("CREATOR");
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setUser(listener);
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        contract.setProducerProfile(profile);
        contract.setStatus("IN_PROGRESS");
        ContractStage stage = new ContractStage();
        stage.setContractStageId(UUID.randomUUID());
        stage.setContract(contract);
        stage.setStatus("DISPUTED");
        MilestoneDispute dispute = new MilestoneDispute();
        dispute.setMilestoneDisputeId(UUID.randomUUID());
        dispute.setContractStage(stage);
        dispute.setRaisedBy(creator);
        dispute.setStatus("AWAITING_RESPONSE");
        dispute.setPreviousStageStatus("SUBMITTED");
        ReflectionTestUtils.setField(dispute, "createdAt", Instant.now().minus(4, ChronoUnit.DAYS));
        when(disputes.findContractIdByDisputeId(dispute.getMilestoneDisputeId()))
                .thenReturn(Optional.of(contract.getContractId()));
        when(contracts.lockById(contract.getContractId())).thenReturn(Optional.of(contract));
        when(disputes.findByIdForUpdate(dispute.getMilestoneDisputeId()))
                .thenReturn(Optional.of(dispute));
        when(disputes.findById(dispute.getMilestoneDisputeId()))
                .thenReturn(Optional.of(dispute));
        when(stages.findById(stage.getContractStageId())).thenReturn(Optional.of(stage));
        when(stages.findByIdForUpdate(stage.getContractStageId())).thenReturn(Optional.of(stage));
        when(disputes.save(any(MilestoneDispute.class))).thenAnswer(call -> call.getArgument(0));

        DisputeResponse result = service.resolveMilestoneDisputeTimeout(dispute.getMilestoneDisputeId());

        assertEquals("CREATOR_WINS", result.decision());
        verify(escrows).resolveCreatorWin(contract.getContractId());
        org.mockito.Mockito.verify(escrows, org.mockito.Mockito.never()).settle(any());
        verify(notifier).notifyResult(listener, creator, dispute.getMilestoneDisputeId(), "CREATOR_WINS");
    }

    @Test
    void creatorWinResetsAutoAcceptanceWaitingPeriod() {
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setStatus("IN_PROGRESS");
        ContractStage stage = new ContractStage();
        stage.setContractStageId(UUID.randomUUID());
        stage.setContract(contract);
        stage.setStatus("SUBMITTED");
        MilestoneSubmission submission = new MilestoneSubmission();
        submission.setContractStage(stage);
        ReflectionTestUtils.setField(submission, "submittedAt", Instant.now().minus(5, ChronoUnit.DAYS));
        MilestoneDispute creatorWin = new MilestoneDispute();
        creatorWin.setResolvedAt(Instant.now().minus(1, ChronoUnit.HOURS));
        when(stages.findById(stage.getContractStageId())).thenReturn(Optional.of(stage));
        when(stages.findByIdForUpdate(stage.getContractStageId())).thenReturn(Optional.of(stage));
        when(contracts.lockById(contract.getContractId())).thenReturn(Optional.of(contract));
        when(escrows.autoAcceptEnabled(contract)).thenReturn(true);
        when(submissions.findFirstByContractStage_ContractStageIdOrderBySubmittedAtDesc(
                stage.getContractStageId())).thenReturn(Optional.of(submission));
        when(disputes.findFirstByContractStage_ContractStageIdAndDecisionOrderByResolvedAtDesc(
                stage.getContractStageId(), "CREATOR_WINS")).thenReturn(Optional.of(creatorWin));

        service.autoApproveMilestone(stage.getContractStageId());

        org.mockito.Mockito.verify(escrows, org.mockito.Mockito.never()).settle(any());
        assertEquals("SUBMITTED", stage.getStatus());
    }

    private MilestoneDispute dispute() {
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setUser(user("LISTENER"));
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(user("CREATOR"));
        profile.setChannelName("Kênh lịch sử");
        contract.setProducerProfile(profile);
        ContractStage stage = new ContractStage();
        stage.setContractStageId(UUID.randomUUID());
        stage.setContract(contract);
        stage.setStageName("Đợt bàn giao");
        stage.setStatus("DISPUTED");
        MilestoneDispute dispute = new MilestoneDispute();
        dispute.setMilestoneDisputeId(UUID.randomUUID());
        dispute.setContractStage(stage);
        dispute.setRaisedBy(user("LISTENER"));
        dispute.setReason("Không đạt");
        dispute.setStatus("OPEN");
        return dispute;
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
