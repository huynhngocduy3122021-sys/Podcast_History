package com.prmteam7.podcasthistory.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "\"Milestone_submission\"", indexes = {
        @Index(name = "idx_milestone_submission_stage_id", columnList = "contract_stage_id")
})
public class MilestoneSubmission extends BaseEntity {

    @jakarta.persistence.Id
    @Column(name = "milestone_submission_id", nullable = false, updatable = false)
    private UUID milestoneSubmissionId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "contract_stage_id", nullable = false)
    private ContractStage contractStage;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "creator_user_id", nullable = false)
    private AppUser creator;

    @Column(name = "revision_number", nullable = false)
    private Integer revisionNumber;

    @Column(name = "object_key", nullable = false, columnDefinition = "text")
    private String objectKey;

    @Column(name = "public_url", columnDefinition = "text")
    private String publicUrl;

    @Column(name = "content_type", nullable = false, length = 150)
    private String contentType;

    @Column(name = "submission_note", columnDefinition = "text")
    private String submissionNote;

    @Column(name = "submitted_at", nullable = false)
    private Instant submittedAt;

    public MilestoneSubmission() {}

    public UUID getMilestoneSubmissionId() { return milestoneSubmissionId; }
    public void setMilestoneSubmissionId(UUID id) { this.milestoneSubmissionId = id; }
    public ContractStage getContractStage() { return contractStage; }
    public void setContractStage(ContractStage contractStage) { this.contractStage = contractStage; }
    public AppUser getCreator() { return creator; }
    public void setCreator(AppUser creator) { this.creator = creator; }
    public Integer getRevisionNumber() { return revisionNumber; }
    public void setRevisionNumber(Integer revisionNumber) { this.revisionNumber = revisionNumber; }
    public String getObjectKey() { return objectKey; }
    public void setObjectKey(String objectKey) { this.objectKey = objectKey; }
    public String getPublicUrl() { return publicUrl; }
    public void setPublicUrl(String publicUrl) { this.publicUrl = publicUrl; }
    public String getContentType() { return contentType; }
    public void setContentType(String contentType) { this.contentType = contentType; }
    public String getSubmissionNote() { return submissionNote; }
    public void setSubmissionNote(String submissionNote) { this.submissionNote = submissionNote; }
    public Instant getSubmittedAt() { return submittedAt; }
    public void setSubmittedAt(Instant submittedAt) { this.submittedAt = submittedAt; }

    @PrePersist
    private void assignIdAndTimestamp() {
        if (milestoneSubmissionId == null) {
            milestoneSubmissionId = UUID.randomUUID();
        }
        if (submittedAt == null) {
            submittedAt = Instant.now();
        }
    }
}
