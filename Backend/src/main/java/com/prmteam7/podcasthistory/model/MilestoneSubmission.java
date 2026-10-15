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
@Table(name = "\"Milestone_submission\"", indexes = {
        @Index(name = "idx_milestone_submission_stage_id", columnList = "contract_stage_id")
})
@Getter
@Setter
@NoArgsConstructor
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
