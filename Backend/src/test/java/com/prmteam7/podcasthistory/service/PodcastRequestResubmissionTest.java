package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.multipart.MultipartFile;

import com.prmteam7.podcasthistory.dto.response.MediaUploadResponse;
import com.prmteam7.podcasthistory.enums.ContractStageStatus;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.Contract;
import com.prmteam7.podcasthistory.model.ContractStage;
import com.prmteam7.podcasthistory.model.MilestoneSubmission;
import com.prmteam7.podcasthistory.model.ProducerProfile;
import com.prmteam7.podcasthistory.model.Role;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.ContractStageRepository;
import com.prmteam7.podcasthistory.repository.ContractRepository;
import com.prmteam7.podcasthistory.repository.MilestoneSubmissionRepository;

@ExtendWith(MockitoExtension.class)
class PodcastRequestResubmissionTest {
    @Mock private AppUserRepository userRepository;
    @Mock private ContractStageRepository stageRepository;
    @Mock private ContractRepository contractRepository;
    @Mock private MilestoneSubmissionRepository submissionRepository;
    @Mock private MediaUploadService mediaUploadService;
    @Mock private ContractEscrowService escrowService;
    @Mock private MultipartFile file;
    @InjectMocks private PodcastRequestService service;

    @Test
    void creatorCanSubmitNewFileAfterListenerRejectsCurrentSubmission() {
        UUID creatorId = UUID.randomUUID();
        UUID stageId = UUID.randomUUID();
        Role role = new Role();
        role.setRoleCode("CREATOR");
        AppUser creator = new AppUser();
        creator.setUserId(creatorId);
        creator.setRole(role);
        creator.setIsActive(true);
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setProducerProfile(profile);
        ContractStage stage = new ContractStage();
        stage.setContractStageId(stageId);
        stage.setContract(contract);
        stage.setStatus(ContractStageStatus.REVISION_REQUESTED.name());
        when(userRepository.findById(creatorId)).thenReturn(Optional.of(creator));
        when(stageRepository.findById(stageId)).thenReturn(Optional.of(stage));
        when(contractRepository.lockById(contract.getContractId())).thenReturn(Optional.of(contract));
        when(stageRepository.findByIdForUpdate(stageId)).thenReturn(Optional.of(stage));
        when(mediaUploadService.uploadMilestoneMedia(file, creatorId, stageId))
                .thenReturn(new MediaUploadResponse("private/new-file", "bucket", null, "audio/mpeg", 100L));
        when(submissionRepository.countByContractStage_ContractStageId(stageId)).thenReturn(1L);
        when(submissionRepository.save(any(MilestoneSubmission.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        service.submitMilestone(creatorId, stageId, file, "Đã thu âm lại");

        ArgumentCaptor<MilestoneSubmission> submission = ArgumentCaptor.forClass(MilestoneSubmission.class);
        verify(submissionRepository).save(submission.capture());
        assertEquals(2, submission.getValue().getRevisionNumber());
        assertEquals("private/new-file", submission.getValue().getObjectKey());
        assertEquals(ContractStageStatus.SUBMITTED.name(), stage.getStatus());
        verify(stageRepository).save(stage);
    }
}
