package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.response.MediaUploadResponse;
import com.prmteam7.podcasthistory.dto.response.MilestoneDraftResponse;
import com.prmteam7.podcasthistory.dto.response.MilestoneSubmissionResponse;
import com.prmteam7.podcasthistory.exception.PodcastWorkflowException;
import com.prmteam7.podcasthistory.exception.PodcastWorkflowNotFoundException;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class MilestoneDraftService {
    private static final List<String> INACTIVE_DRAFT_STATUSES = List.of("CANCELLED", "DELIVERED");
    private final AppUserRepository users;
    private final ContractRepository contracts;
    private final ContractStageRepository stages;
    private final MilestoneDraftRepository drafts;
    private final MilestoneSubmissionRepository submissions;
    private final MediaUploadService uploads;
    private final ContractEscrowService escrows;
    private final R2PlaybackUrlService playback;

    public MilestoneDraftService(AppUserRepository users, ContractRepository contracts,
            ContractStageRepository stages, MilestoneDraftRepository drafts,
            MilestoneSubmissionRepository submissions, MediaUploadService uploads,
            ContractEscrowService escrows, R2PlaybackUrlService playback) {
        this.users = users;
        this.contracts = contracts;
        this.stages = stages;
        this.drafts = drafts;
        this.submissions = submissions;
        this.uploads = uploads;
        this.escrows = escrows;
        this.playback = playback;
    }

    @Transactional
    public MilestoneDraftResponse upload(UUID creatorId, UUID stageId, MultipartFile file, String note) {
        AppUser creator = activeCreator(creatorId);
        if (note != null && note.length() > 5000)
            throw new PodcastWorkflowException("Ghi chú không được vượt quá 5000 ký tự.");
        ContractStage stage = lockedOwnedStage(creatorId, stageId);
        requireDraftable(stage);
        MediaUploadResponse media = uploads.uploadMilestoneMedia(file, creatorId, stageId);
        MilestoneDraft draft = new MilestoneDraft();
        draft.setStage(stage);
        draft.setCreator(creator);
        draft.setDraftNumber(Math.toIntExact(drafts.countByStage_ContractStageId(stageId) + 1));
        draft.setObjectKey(media.objectKey());
        draft.setContentType(media.contentType());
        draft.setNote(note == null || note.isBlank() ? null : note.trim());
        draft.setStatus("PENDING");
        return toResponse(drafts.saveAndFlush(draft));
    }

    @Transactional(readOnly = true)
    public List<MilestoneDraftResponse> list(UUID creatorId, UUID stageId) {
        activeCreator(creatorId);
        ContractStage stage = stages.findById(stageId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy đợt."));
        requireOwner(stage, creatorId);
        return drafts.findAllByStage_ContractStageIdOrderByDraftNumberDesc(stageId)
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public DraftMediaUrl media(UUID creatorId, UUID stageId, UUID draftId) {
        activeCreator(creatorId);
        ContractStage stage = stages.findById(stageId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy đợt."));
        requireOwner(stage, creatorId);
        MilestoneDraft draft = drafts.findById(draftId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy bản nháp."));
        if (!stageId.equals(draft.getStage().getContractStageId()))
            throw new PodcastWorkflowNotFoundException("Bản nháp không thuộc đợt này.");
        var signed = playback.create(draft.getObjectKey(), true);
        return new DraftMediaUrl(draftId, signed.url(), signed.expiresAt());
    }

    @Transactional
    public MilestoneSubmissionResponse deliver(UUID creatorId, UUID stageId, UUID draftId) {
        activeCreator(creatorId);
        ContractStage stage = lockedOwnedStage(creatorId, stageId);
        requireDraftable(stage);
        MilestoneDraft latest = drafts.findFirstByStage_ContractStageIdAndStatusNotInOrderByDraftNumberDesc(
                        stageId, INACTIVE_DRAFT_STATUSES)
                .orElseThrow(() -> new PodcastWorkflowException("CC chưa upload bản nháp."));
        if (!latest.getId().equals(draftId))
            throw new PodcastWorkflowException("Chỉ bản nháp mới nhất được bàn giao.");
        MilestoneDraft draft = drafts.lockById(draftId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy bản nháp."));
        if (!stageId.equals(draft.getStage().getContractStageId())
                || !creatorId.equals(draft.getCreator().getUserId())
                || !"APPROVED".equals(draft.getStatus())
                || !"SAFE".equals(draft.getAiLabel())
                || !"APPROVE".equals(draft.getAiRecommendation()))
            throw new PodcastWorkflowException("Bản nháp mới nhất chưa được AI duyệt an toàn lời nói.");
        MilestoneSubmission submission = new MilestoneSubmission();
        submission.setContractStage(stage);
        submission.setCreator(draft.getCreator());
        submission.setRevisionNumber(Math.toIntExact(submissions.countByContractStage_ContractStageId(stageId) + 1));
        submission.setObjectKey(draft.getObjectKey());
        submission.setPublicUrl(null);
        submission.setContentType(draft.getContentType());
        submission.setSubmissionNote(draft.getNote());
        submission = submissions.saveAndFlush(submission);
        draft.setStatus("DELIVERED");
        draft.setDeliveredAt(Instant.now());
        drafts.save(draft);
        stage.setStatus("SUBMITTED");
        stages.save(stage);
        return new MilestoneSubmissionResponse(submission.getMilestoneSubmissionId(), stageId,
                submission.getRevisionNumber(), submission.getObjectKey(), null,
                submission.getContentType(), submission.getSubmissionNote(), submission.getSubmittedAt());
    }

    @Transactional
    public MilestoneDraftResponse cancel(UUID creatorId, UUID stageId, UUID draftId) {
        activeCreator(creatorId);
        ContractStage stage = lockedOwnedStage(creatorId, stageId);
        requireDraftable(stage);
        MilestoneDraft draft = drafts.lockById(draftId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy bản nháp."));
        if (!stageId.equals(draft.getStage().getContractStageId())
                || !creatorId.equals(draft.getCreator().getUserId()))
            throw new PodcastWorkflowNotFoundException("Bản nháp không thuộc đợt này.");
        if ("CANCELLED".equals(draft.getStatus())) return toResponse(draft);
        MilestoneDraft latest = drafts.findFirstByStage_ContractStageIdAndStatusNotInOrderByDraftNumberDesc(
                        stageId, INACTIVE_DRAFT_STATUSES)
                .orElseThrow(() -> new PodcastWorkflowException("Không có bản nháp để hủy."));
        if (!latest.getId().equals(draftId))
            throw new PodcastWorkflowException("Chỉ hủy được bản nháp mới nhất chưa bàn giao.");
        draft.setStatus("CANCELLED");
        draft.setAttemptToken(null);
        draft.setProcessingStartedAt(null);
        return toResponse(drafts.save(draft));
    }

    private ContractStage lockedOwnedStage(UUID creatorId, UUID stageId) {
        ContractStage snapshot = stages.findById(stageId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy đợt."));
        contracts.lockById(snapshot.getContract().getContractId())
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy hợp đồng."));
        ContractStage stage = stages.findByIdForUpdate(stageId).orElseThrow();
        requireOwner(stage, creatorId);
        return stage;
    }

    private void requireDraftable(ContractStage stage) {
        if (!escrows.isEscrowContract(stage.getContract()))
            throw new PodcastWorkflowException("API bản nháp AI chỉ dành cho hợp đồng giữ tiền.");
        escrows.requireActiveSigned(stage.getContract());
        escrows.requirePreviousStagesApproved(stage);
        if (!"NOT_STARTED".equals(stage.getStatus()) && !"REVISION_REQUESTED".equals(stage.getStatus()))
            throw new PodcastWorkflowException("Đợt không ở trạng thái cho phép chuẩn bị bản bàn giao.");
    }

    private AppUser activeCreator(UUID creatorId) {
        AppUser user = users.findById(creatorId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy CC."));
        if (!Boolean.TRUE.equals(user.getIsActive()) || user.getRole() == null
                || !"CREATOR".equalsIgnoreCase(user.getRole().getRoleCode()))
            throw new PodcastWorkflowException("Tài khoản không có quyền CC hoặc không hoạt động.");
        return user;
    }

    private void requireOwner(ContractStage stage, UUID creatorId) {
        if (!creatorId.equals(stage.getContract().getProducerProfile().getUser().getUserId()))
            throw new PodcastWorkflowException("Đợt không thuộc kênh CC này.");
    }

    private MilestoneDraftResponse toResponse(MilestoneDraft draft) {
        return new MilestoneDraftResponse(draft.getId(), draft.getStage().getContractStageId(),
                draft.getDraftNumber(), draft.getStatus(), draft.getContentType(), draft.getNote(),
                draft.getAiLabel(), draft.getAiRecommendation(), draft.getAiConfidence(),
                draft.getAiReason(), draft.getErrorMessage(), draft.getCreatedAt(),
                draft.getReviewedAt(), draft.getDeliveredAt());
    }

    public record DraftMediaUrl(UUID draftId, String url, Instant expiresAt) {}
}
