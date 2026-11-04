package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import com.prmteam7.podcasthistory.dto.response.MediaUploadResponse;
import com.prmteam7.podcasthistory.exception.PodcastWorkflowException;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.multipart.MultipartFile;

@ExtendWith(MockitoExtension.class)
class MilestoneDraftServiceTest {
    @Mock AppUserRepository users;
    @Mock ContractRepository contracts;
    @Mock ContractStageRepository stages;
    @Mock MilestoneDraftRepository drafts;
    @Mock MilestoneSubmissionRepository submissions;
    @Mock MediaUploadService uploads;
    @Mock ContractEscrowService escrows;
    @Mock R2PlaybackUrlService playback;
    @Mock MultipartFile file;
    @InjectMocks MilestoneDraftService service;

    private AppUser creator;
    private ContractStage stage;

    @BeforeEach
    void fixture() {
        Role role = new Role();
        role.setRoleCode("CREATOR");
        creator = new AppUser();
        creator.setUserId(UUID.randomUUID());
        creator.setRole(role);
        creator.setIsActive(true);
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setProducerProfile(profile);
        contract.setStatus("IN_PROGRESS");
        stage = new ContractStage();
        stage.setContractStageId(UUID.randomUUID());
        stage.setContract(contract);
        stage.setStatus("NOT_STARTED");
    }

    private void allowStage() {
        when(users.findById(creator.getUserId())).thenReturn(Optional.of(creator));
        when(stages.findById(stage.getContractStageId())).thenReturn(Optional.of(stage));
        when(contracts.lockById(stage.getContract().getContractId())).thenReturn(Optional.of(stage.getContract()));
        when(stages.findByIdForUpdate(stage.getContractStageId())).thenReturn(Optional.of(stage));
        when(escrows.isEscrowContract(stage.getContract())).thenReturn(true);
    }

    @Test
    void uploadingDraftDoesNotDeliverOrStartListenerReviewClock() {
        allowStage();
        when(uploads.uploadMilestoneMedia(file, creator.getUserId(), stage.getContractStageId()))
                .thenReturn(new MediaUploadResponse("private/draft-1", "bucket", null, "audio/mpeg", 100L));
        when(drafts.saveAndFlush(any(MilestoneDraft.class))).thenAnswer(call -> {
            MilestoneDraft draft = call.getArgument(0);
            draft.setId(UUID.randomUUID());
            return draft;
        });

        var result = service.upload(creator.getUserId(), stage.getContractStageId(), file, "Bản nháp");

        assertEquals("PENDING", result.status());
        assertEquals("NOT_STARTED", stage.getStatus());
        verify(submissions, never()).saveAndFlush(any());
        verify(stages, never()).save(stage);
    }

    @Test
    void cannotDeliverDraftBeforeAiApproval() {
        allowStage();
        MilestoneDraft draft = draft("PROCESSING");
        when(drafts.findFirstByStage_ContractStageIdAndStatusNotInOrderByDraftNumberDesc(
                stage.getContractStageId(), List.of("CANCELLED", "DELIVERED")))
                .thenReturn(Optional.of(draft));
        when(drafts.lockById(draft.getId())).thenReturn(Optional.of(draft));

        assertThrows(PodcastWorkflowException.class, () -> service.deliver(
                creator.getUserId(), stage.getContractStageId(), draft.getId()));

        verify(submissions, never()).saveAndFlush(any());
        assertEquals("NOT_STARTED", stage.getStatus());
    }

    @Test
    void approvedOldDraftCannotBypassReviewOfNewerDraft() {
        allowStage();
        MilestoneDraft latest = draft("PENDING");
        when(drafts.findFirstByStage_ContractStageIdAndStatusNotInOrderByDraftNumberDesc(
                stage.getContractStageId(), List.of("CANCELLED", "DELIVERED")))
                .thenReturn(Optional.of(latest));

        assertThrows(PodcastWorkflowException.class, () -> service.deliver(
                creator.getUserId(), stage.getContractStageId(), UUID.randomUUID()));

        verify(drafts, never()).lockById(any());
        verify(submissions, never()).saveAndFlush(any());
    }

    @Test
    void approvedLatestDraftNeedsExplicitCreatorDelivery() {
        allowStage();
        MilestoneDraft draft = draft("APPROVED");
        draft.setAiLabel("SAFE");
        draft.setAiRecommendation("APPROVE");
        when(drafts.findFirstByStage_ContractStageIdAndStatusNotInOrderByDraftNumberDesc(
                stage.getContractStageId(), List.of("CANCELLED", "DELIVERED")))
                .thenReturn(Optional.of(draft));
        when(drafts.lockById(draft.getId())).thenReturn(Optional.of(draft));
        when(submissions.saveAndFlush(any(MilestoneSubmission.class))).thenAnswer(call -> {
            MilestoneSubmission submission = call.getArgument(0);
            submission.setMilestoneSubmissionId(UUID.randomUUID());
            submission.setSubmittedAt(Instant.now());
            return submission;
        });

        var result = service.deliver(creator.getUserId(), stage.getContractStageId(), draft.getId());

        assertNotNull(result.submissionId());
        assertEquals("SUBMITTED", stage.getStatus());
        assertEquals("DELIVERED", draft.getStatus());
        assertNotNull(draft.getDeliveredAt());
        verify(submissions).saveAndFlush(any());
    }

    @Test
    void cancellingProcessingLatestDraftAllowsEarlierApprovedDraftToBeDelivered() {
        allowStage();
        MilestoneDraft newest = draft("PROCESSING");
        newest.setDraftNumber(2);
        newest.setAttemptToken(UUID.randomUUID());
        MilestoneDraft earlier = draft("APPROVED");
        earlier.setDraftNumber(1);
        earlier.setAiLabel("SAFE");
        earlier.setAiRecommendation("APPROVE");
        when(drafts.lockById(newest.getId())).thenReturn(Optional.of(newest));
        when(drafts.findFirstByStage_ContractStageIdAndStatusNotInOrderByDraftNumberDesc(
                stage.getContractStageId(), List.of("CANCELLED", "DELIVERED")))
                .thenReturn(Optional.of(newest), Optional.of(earlier));
        when(drafts.save(newest)).thenReturn(newest);
        when(drafts.lockById(earlier.getId())).thenReturn(Optional.of(earlier));
        when(submissions.saveAndFlush(any(MilestoneSubmission.class))).thenAnswer(call -> {
            MilestoneSubmission submission = call.getArgument(0);
            submission.setMilestoneSubmissionId(UUID.randomUUID());
            submission.setSubmittedAt(Instant.now());
            return submission;
        });

        var cancelled = service.cancel(creator.getUserId(), stage.getContractStageId(), newest.getId());
        var delivered = service.deliver(creator.getUserId(), stage.getContractStageId(), earlier.getId());

        assertEquals("CANCELLED", cancelled.status());
        assertNull(newest.getAttemptToken());
        assertEquals("DELIVERED", earlier.getStatus());
        assertNotNull(delivered.submissionId());
        assertEquals("SUBMITTED", stage.getStatus());
    }

    @Test
    void cannotCancelOlderDraftWhileNewerOneIsActive() {
        allowStage();
        MilestoneDraft older = draft("APPROVED");
        MilestoneDraft newer = draft("PROCESSING");
        when(drafts.lockById(older.getId())).thenReturn(Optional.of(older));
        when(drafts.findFirstByStage_ContractStageIdAndStatusNotInOrderByDraftNumberDesc(
                stage.getContractStageId(), List.of("CANCELLED", "DELIVERED")))
                .thenReturn(Optional.of(newer));

        assertThrows(PodcastWorkflowException.class,
                () -> service.cancel(creator.getUserId(), stage.getContractStageId(), older.getId()));
        assertEquals("APPROVED", older.getStatus());
        verify(drafts, never()).save(any());
    }

    private MilestoneDraft draft(String status) {
        MilestoneDraft draft = new MilestoneDraft();
        draft.setId(UUID.randomUUID());
        draft.setStage(stage);
        draft.setCreator(creator);
        draft.setObjectKey("private/media");
        draft.setContentType("audio/mpeg");
        draft.setStatus(status);
        return draft;
    }
}
