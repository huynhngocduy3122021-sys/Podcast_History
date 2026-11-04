package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.prmteam7.podcasthistory.enums.ContractStageStatus;
import com.prmteam7.podcasthistory.exception.PodcastWorkflowException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.Contract;
import com.prmteam7.podcasthistory.model.ContractStage;
import com.prmteam7.podcasthistory.model.MilestoneRevision;
import com.prmteam7.podcasthistory.model.Role;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.ContractStageRepository;
import com.prmteam7.podcasthistory.repository.ContractRepository;
import com.prmteam7.podcasthistory.repository.MilestoneRevisionRepository;

@ExtendWith(MockitoExtension.class)
class PodcastRequestRevisionTest {

    @Mock private AppUserRepository userRepository;
    @Mock private ContractStageRepository stageRepository;
    @Mock private ContractRepository contractRepository;
    @Mock private ContractEscrowService escrowService;
    @Mock private MilestoneRevisionRepository revisionRepository;
    @InjectMocks private PodcastRequestService service;

    private final UUID listenerId = UUID.randomUUID();
    private final UUID stageId = UUID.randomUUID();
    private ContractStage stage;

    @BeforeEach
    void setUp() {
        Role role = new Role();
        role.setRoleCode("LISTENER");
        AppUser listener = new AppUser();
        listener.setUserId(listenerId);
        listener.setRole(role);
        listener.setIsActive(true);
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setUser(listener);
        stage = new ContractStage();
        stage.setContractStageId(stageId);
        stage.setContract(contract);
        stage.setStatus(ContractStageStatus.SUBMITTED.name());
        when(userRepository.findById(listenerId)).thenReturn(Optional.of(listener));
        when(stageRepository.findById(stageId)).thenReturn(Optional.of(stage));
        when(contractRepository.lockById(contract.getContractId())).thenReturn(Optional.of(contract));
        when(stageRepository.findByIdForUpdate(stageId)).thenReturn(Optional.of(stage));
    }

    @Test
    void rejectingSubmissionRequestsReworkWithoutApprovalOrPayment() {
        when(revisionRepository.countByContractStage_ContractStageIdAndRequestedBy_UserId(stageId, listenerId))
                .thenReturn(2L);
        when(revisionRepository.countByContractStage_ContractStageId(stageId)).thenReturn(2L);

        service.requestMilestoneRevision(listenerId, stageId, "Âm thanh chưa đạt");

        assertEquals(ContractStageStatus.REVISION_REQUESTED.name(), stage.getStatus());
        verify(revisionRepository).save(any(MilestoneRevision.class));
        verify(stageRepository).save(stage);
    }

    @Test
    void fourthListenerRejectionIsBlockedAndDoesNotMutateStage() {
        when(revisionRepository.countByContractStage_ContractStageIdAndRequestedBy_UserId(stageId, listenerId))
                .thenReturn(3L);

        assertThrows(PodcastWorkflowException.class,
                () -> service.requestMilestoneRevision(listenerId, stageId, "Làm lại lần nữa"));

        assertEquals(ContractStageStatus.SUBMITTED.name(), stage.getStatus());
        verify(revisionRepository, never()).save(any());
        verify(stageRepository, never()).save(any());
    }
}
