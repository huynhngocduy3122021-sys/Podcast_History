package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "producer_verification", indexes = {
        @Index(name = "idx_producer_verification_producer_profile_id", columnList = "producer_profile_id"),
        @Index(name = "idx_producer_verification_reviewer_user_id", columnList = "reviewer_user_id")
    })
public class ProducerVerification extends BaseEntity {
    @Id
    @Column(name = "producer_verification_id", nullable = false, updatable = false)
    private UUID producerVerificationId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "producer_profile_id", nullable = false)
    private ProducerProfile producerProfile;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "reviewer_user_id", nullable = false)
    private AppUser reviewerUser;

    @Column(name = "document_url", nullable = true, columnDefinition = "text")
    private String documentUrl;

    @Column(name = "verification_status", nullable = false, length = 30)
    private String verificationStatus;

    @Column(name = "note", nullable = true, columnDefinition = "text")
    private String note;

    @Column(name = "submitted_at", nullable = false)
    private Instant submittedAt;

    @Column(name = "verified_at", nullable = true)
    private Instant verifiedAt;

    public ProducerVerification() {
    }

    @PrePersist
    private void assignId() {
        if (producerVerificationId == null) {
            producerVerificationId = UUID.randomUUID();
        }
    }

    public UUID getProducerVerificationId() {
        return producerVerificationId;
    }

    public void setProducerVerificationId(UUID producerVerificationId) {
        this.producerVerificationId = producerVerificationId;
    }

    public ProducerProfile getProducerProfile() {
        return producerProfile;
    }

    public void setProducerProfile(ProducerProfile producerProfile) {
        this.producerProfile = producerProfile;
    }

    public AppUser getReviewerUser() {
        return reviewerUser;
    }

    public void setReviewerUser(AppUser reviewerUser) {
        this.reviewerUser = reviewerUser;
    }

    public String getDocumentUrl() {
        return documentUrl;
    }

    public void setDocumentUrl(String documentUrl) {
        this.documentUrl = documentUrl;
    }

    public String getVerificationStatus() {
        return verificationStatus;
    }

    public void setVerificationStatus(String verificationStatus) {
        this.verificationStatus = verificationStatus;
    }

    public String getNote() {
        return note;
    }

    public void setNote(String note) {
        this.note = note;
    }

    public Instant getSubmittedAt() {
        return submittedAt;
    }

    public void setSubmittedAt(Instant submittedAt) {
        this.submittedAt = submittedAt;
    }

    public Instant getVerifiedAt() {
        return verifiedAt;
    }

    public void setVerifiedAt(Instant verifiedAt) {
        this.verifiedAt = verifiedAt;
    }

}
