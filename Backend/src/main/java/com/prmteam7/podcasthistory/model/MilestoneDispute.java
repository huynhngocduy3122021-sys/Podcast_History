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
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "\"Milestone_dispute\"", indexes = {
        @Index(name = "idx_milestone_dispute_status", columnList = "status"),
        @Index(name = "idx_milestone_dispute_stage_id", columnList = "contract_stage_id")
})
@Getter
@Setter
@NoArgsConstructor
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

    @PrePersist
    private void assignId() {
        if (milestoneDisputeId == null) {
            milestoneDisputeId = UUID.randomUUID();
        }
    }
}
