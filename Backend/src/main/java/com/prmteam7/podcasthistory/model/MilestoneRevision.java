package com.prmteam7.podcasthistory.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "\"Milestone_revision\"", uniqueConstraints = {
        @UniqueConstraint(name = "uk_milestone_revision_number", columnNames = {"contract_stage_id", "revision_number"})
}, indexes = {
        @Index(name = "idx_milestone_revision_stage_id", columnList = "contract_stage_id")
})
@Getter
@Setter
@NoArgsConstructor
public class MilestoneRevision extends BaseEntity {

    @jakarta.persistence.Id
    @Column(name = "milestone_revision_id", nullable = false, updatable = false)
    private UUID milestoneRevisionId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "contract_stage_id", nullable = false)
    private ContractStage contractStage;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "requested_by_user_id", nullable = false)
    private AppUser requestedBy;

    @Column(name = "revision_number", nullable = false)
    private Integer revisionNumber;

    @Column(name = "reason", nullable = false, columnDefinition = "text")
    private String reason;

    @PrePersist
    private void assignId() {
        if (milestoneRevisionId == null) {
            milestoneRevisionId = UUID.randomUUID();
        }
    }
}
