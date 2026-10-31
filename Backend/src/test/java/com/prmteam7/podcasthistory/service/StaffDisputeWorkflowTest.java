package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.prmteam7.podcasthistory.dto.request.ResolveDisputeRequest;
import com.prmteam7.podcasthistory.enums.MilestoneDisputeDecision;
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
    @Mock ContractEscrowService escrows;
    @Mock DisputeStaffNotifier notifier;
    @Mock AdminSupportService support;
    @Mock ContractDisputeRepository contractDisputes;
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
                contractDisputes, null, null, notifier);

        assertEquals(0, queue.disputes(staffId, "OPEN", 0, 20).getTotalElements());
        assertEquals(0, queue.disputes(adminId, "OPEN", 0, 20).getTotalElements());
        verify(support).actor(staffId, false);
        verify(support).actor(adminId, false);
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
                contractDisputes, null, null, notifier);

        var result = queue.open(listener.getUserId(), contract.getContractId(), "Muốn chấm dứt");

        assertEquals("OPEN", result.status());
        assertEquals("DISPUTED", contract.getStatus());
        verify(notifier).notifyOpen("hợp đồng", result.disputeId());
    }

    private MilestoneDispute dispute() {
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        ContractStage stage = new ContractStage();
        stage.setContractStageId(UUID.randomUUID());
        stage.setContract(contract);
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
