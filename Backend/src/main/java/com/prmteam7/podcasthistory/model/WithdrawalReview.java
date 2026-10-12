package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "\"Withdrawal_review\"", indexes = {
        @Index(name = "idx_withdrawal_review_withdrawal_request_id", columnList = "withdrawal_request_id"),
        @Index(name = "idx_withdrawal_review_reviewer_user_id", columnList = "reviewer_user_id")
    })
public class WithdrawalReview extends BaseEntity {
    @Id
    @Column(name = "withdrawal_review_id", nullable = false, updatable = false)
    private UUID withdrawalReviewId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "withdrawal_request_id", nullable = false)
    private WithdrawalRequest withdrawalRequest;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "reviewer_user_id", nullable = false)
    private AppUser reviewerUser;

    @Column(name = "decision", nullable = false, length = 30)
    private String decision;

    @Column(name = "note", nullable = true, columnDefinition = "text")
    private String note;

    @Column(name = "reviewed_at", nullable = false)
    private Instant reviewedAt;

    public WithdrawalReview() {
    }

    @PrePersist
    private void assignId() {
        if (withdrawalReviewId == null) {
            withdrawalReviewId = UUID.randomUUID();
        }
    }

    public UUID getWithdrawalReviewId() {
        return withdrawalReviewId;
    }

    public void setWithdrawalReviewId(UUID withdrawalReviewId) {
        this.withdrawalReviewId = withdrawalReviewId;
    }

    public WithdrawalRequest getWithdrawalRequest() {
        return withdrawalRequest;
    }

    public void setWithdrawalRequest(WithdrawalRequest withdrawalRequest) {
        this.withdrawalRequest = withdrawalRequest;
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
