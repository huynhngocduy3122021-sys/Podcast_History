package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "\"Moderation_Review\"", indexes = {
        @Index(name = "idx_moderation_review_report_id", columnList = "report_id"),
        @Index(name = "idx_moderation_review_moderation_result_id", columnList = "moderation_result_id"),
        @Index(name = "idx_moderation_review_podcast_id", columnList = "podcast_id"),
        @Index(name = "idx_moderation_review_reviewer_user_id", columnList = "reviewer_user_id")
    })
public class ModerationReview extends BaseEntity {
    @Id
    @Column(name = "moderation_review_id", nullable = false, updatable = false)
    private UUID moderationReviewId;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "report_id", nullable = true)
    private Report report;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "moderation_result_id", nullable = true)
    private AiModerationResult moderationResult;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "podcast_id", nullable = true)
    private Podcast podcast;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "reviewer_user_id", nullable = true)
    private AppUser reviewerUser;

    @Column(name = "decision", nullable = false, length = 30)
    private String decision;

    @Column(name = "note", nullable = true, columnDefinition = "text")
    private String note;

    @Column(name = "reviewed_at", nullable = false)
    private Instant reviewedAt;

    public ModerationReview() {
    }

    @PrePersist
    private void assignId() {
        if (moderationReviewId == null) {
            moderationReviewId = UUID.randomUUID();
        }
    }

    public UUID getModerationReviewId() {
        return moderationReviewId;
    }

    public void setModerationReviewId(UUID moderationReviewId) {
        this.moderationReviewId = moderationReviewId;
    }

    public Report getReport() {
        return report;
    }

    public void setReport(Report report) {
        this.report = report;
    }

    public AiModerationResult getModerationResult() {
        return moderationResult;
    }

    public void setModerationResult(AiModerationResult moderationResult) {
        this.moderationResult = moderationResult;
    }

    public Podcast getPodcast() {
        return podcast;
    }

    public void setPodcast(Podcast podcast) {
        this.podcast = podcast;
    }

    public AppUser getReviewerUser() {
        return reviewerUser;
    }

    public void setReviewerUser(AppUser reviewerUser) {
        this.reviewerUser = reviewerUser;
    }

    public String getDecision() {
        return decision;
    }

    public void setDecision(String decision) {
        this.decision = decision;
    }

    public String getNote() {
        return note;
    }

    public void setNote(String note) {
        this.note = note;
    }

    public Instant getReviewedAt() {
        return reviewedAt;
    }

    public void setReviewedAt(Instant reviewedAt) {
        this.reviewedAt = reviewedAt;
    }

}
