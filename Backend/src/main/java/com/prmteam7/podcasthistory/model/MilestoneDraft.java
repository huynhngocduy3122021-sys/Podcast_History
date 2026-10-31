package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "milestone_draft", uniqueConstraints = {
        @UniqueConstraint(name = "uk_milestone_draft_number", columnNames = {"contract_stage_id", "draft_number"})
})
public class MilestoneDraft extends BaseEntity {
    @Id
    @Column(name = "draft_id", nullable = false, updatable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "contract_stage_id", nullable = false)
    private ContractStage stage;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "creator_user_id", nullable = false)
    private AppUser creator;

    @Column(name = "draft_number", nullable = false)
    private int draftNumber;

    @Column(name = "object_key", nullable = false, columnDefinition = "text")
    private String objectKey;

    @Column(name = "content_type", nullable = false, length = 150)
    private String contentType;

    @Column(name = "note", columnDefinition = "text")
    private String note;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    @Column(name = "ai_label", length = 20)
    private String aiLabel;

    @Column(name = "ai_recommendation", length = 20)
    private String aiRecommendation;

    @Column(name = "ai_confidence", precision = 5, scale = 4)
    private BigDecimal aiConfidence;

    @Column(name = "ai_reason", length = 2000)
    private String aiReason;

    @Column(name = "error_message", length = 500)
    private String errorMessage;

    @Column(name = "attempt_token")
    private UUID attemptToken;

    @Column(name = "processing_started_at")
    private Instant processingStartedAt;

    @Column(name = "reviewed_at")
    private Instant reviewedAt;

    @Column(name = "delivered_at")
    private Instant deliveredAt;

    @PrePersist
    private void assignId() { if (id == null) id = UUID.randomUUID(); }

    public UUID getId() { return id; }
    public void setId(UUID value) { id = value; }
    public ContractStage getStage() { return stage; }
    public void setStage(ContractStage value) { stage = value; }
    public AppUser getCreator() { return creator; }
    public void setCreator(AppUser value) { creator = value; }
    public int getDraftNumber() { return draftNumber; }
    public void setDraftNumber(int value) { draftNumber = value; }
    public String getObjectKey() { return objectKey; }
    public void setObjectKey(String value) { objectKey = value; }
    public String getContentType() { return contentType; }
    public void setContentType(String value) { contentType = value; }
    public String getNote() { return note; }
    public void setNote(String value) { note = value; }
    public String getStatus() { return status; }
    public void setStatus(String value) { status = value; }
    public String getAiLabel() { return aiLabel; }
    public void setAiLabel(String value) { aiLabel = value; }
    public String getAiRecommendation() { return aiRecommendation; }
    public void setAiRecommendation(String value) { aiRecommendation = value; }
    public BigDecimal getAiConfidence() { return aiConfidence; }
    public void setAiConfidence(BigDecimal value) { aiConfidence = value; }
    public String getAiReason() { return aiReason; }
    public void setAiReason(String value) { aiReason = value; }
    public String getErrorMessage() { return errorMessage; }
    public void setErrorMessage(String value) { errorMessage = value; }
    public UUID getAttemptToken() { return attemptToken; }
    public void setAttemptToken(UUID value) { attemptToken = value; }
    public Instant getProcessingStartedAt() { return processingStartedAt; }
    public void setProcessingStartedAt(Instant value) { processingStartedAt = value; }
    public Instant getReviewedAt() { return reviewedAt; }
    public void setReviewedAt(Instant value) { reviewedAt = value; }
    public Instant getDeliveredAt() { return deliveredAt; }
    public void setDeliveredAt(Instant value) { deliveredAt = value; }
}
