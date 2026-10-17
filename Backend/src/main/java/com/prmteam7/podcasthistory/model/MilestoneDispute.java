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
@Table(name = "\"Milestone_dispute\"", indexes = {
        @Index(name = "idx_milestone_dispute_status", columnList = "status"),
        @Index(name = "idx_milestone_dispute_stage_id", columnList = "contract_stage_id")
})
public class MilestoneDispute extends BaseEntity {

    @jakarta.persistence.Id
    @Column(name = "milestone_dispute_id", nullable = false, updatable = false)
    private UUID milestoneDisputeId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "contract_stage_id", nullable = false)
    private ContractStage contractStage;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "raised_by_user_id", nullable = false)
    private AppUser raisedBy;

    @Column(name = "reason", nullable = false, columnDefinition = "text")
    private String reason;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reviewed_by_user_id")
    private AppUser reviewedBy;

    @Column(name = "decision", length = 40)
    private String decision;

    @Column(name = "resolution_note", columnDefinition = "text")
    private String resolutionNote;

    @Column(name = "resolved_at")
    private Instant resolvedAt;

    public MilestoneDispute() {}

    public UUID getMilestoneDisputeId() { return milestoneDisputeId; }
    public void setMilestoneDisputeId(UUID id) { this.milestoneDisputeId = id; }
    public ContractStage getContractStage() { return contractStage; }
    public void setContractStage(ContractStage contractStage) { this.contractStage = contractStage; }
    public AppUser getRaisedBy() { return raisedBy; }
    public void setRaisedBy(AppUser raisedBy) { this.raisedBy = raisedBy; }
    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public AppUser getReviewedBy() { return reviewedBy; }
    public void setReviewedBy(AppUser reviewedBy) { this.reviewedBy = reviewedBy; }
    public String getDecision() { return decision; }
    public void setDecision(String decision) { this.decision = decision; }
    public String getResolutionNote() { return resolutionNote; }
    public void setResolutionNote(String resolutionNote) { this.resolutionNote = resolutionNote; }
    public Instant getResolvedAt() { return resolvedAt; }
    public void setResolvedAt(Instant resolvedAt) { this.resolvedAt = resolvedAt; }

    @PrePersist
    private void assignId() {
        if (milestoneDisputeId == null) {
            milestoneDisputeId = UUID.randomUUID();
        }
    }
}
