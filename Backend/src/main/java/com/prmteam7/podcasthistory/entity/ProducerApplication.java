package com.prmteam7.podcasthistory.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "producer_application", indexes = {
        @Index(name = "idx_producer_application_user_id", columnList = "user_id")
    })
public class ProducerApplication extends BaseEntity {
    @Id
    @Column(name = "producer_application_id", nullable = false, updatable = false)
    private UUID producerApplicationId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @Column(name = "channel_name", nullable = false, length = 150)
    private String channelName;

    @Column(name = "introduction", nullable = false, columnDefinition = "text")
    private String introduction;

    @Column(name = "portfolio_url", nullable = true, columnDefinition = "text")
    private String portfolioUrl;

    @Column(name = "application_status", nullable = false, length = 30)
    private String applicationStatus;

    @Column(name = "review_note", nullable = true, columnDefinition = "text")
    private String reviewNote;

    @Column(name = "submitted_at", nullable = false)
    private Instant submittedAt;

    @Column(name = "reviewed_at", nullable = true)
    private Instant reviewedAt;

    public ProducerApplication() {
    }

    @PrePersist
    private void assignId() {
        if (producerApplicationId == null) {
            producerApplicationId = UUID.randomUUID();
        }
    }

    public UUID getProducerApplicationId() {
        return producerApplicationId;
    }

    public void setProducerApplicationId(UUID producerApplicationId) {
        this.producerApplicationId = producerApplicationId;
    }

    public AppUser getUser() {
        return user;
    }

    public void setUser(AppUser user) {
        this.user = user;
    }

    public String getChannelName() {
        return channelName;
    }

    public void setChannelName(String channelName) {
        this.channelName = channelName;
    }

    public String getIntroduction() {
        return introduction;
    }

    public void setIntroduction(String introduction) {
        this.introduction = introduction;
    }

    public String getPortfolioUrl() {
        return portfolioUrl;
    }

    public void setPortfolioUrl(String portfolioUrl) {
        this.portfolioUrl = portfolioUrl;
    }

    public String getApplicationStatus() {
        return applicationStatus;
    }

    public void setApplicationStatus(String applicationStatus) {
        this.applicationStatus = applicationStatus;
    }

    public String getReviewNote() {
        return reviewNote;
    }

    public void setReviewNote(String reviewNote) {
        this.reviewNote = reviewNote;
    }

    public Instant getSubmittedAt() {
        return submittedAt;
    }

    public void setSubmittedAt(Instant submittedAt) {
        this.submittedAt = submittedAt;
    }

    public Instant getReviewedAt() {
        return reviewedAt;
    }

    public void setReviewedAt(Instant reviewedAt) {
        this.reviewedAt = reviewedAt;
    }

}
