package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "\"Creator_profile\"", uniqueConstraints = {
        @UniqueConstraint(name = "uk_producer_profile_channel_name", columnNames = {"channel_name"})
    }, indexes = {
        @Index(name = "idx_producer_profile_user_id", columnList = "user_id")
    })
public class ProducerProfile extends UpdatedEntity {
    @Id
    @Column(name = "producer_profile_id", nullable = false, updatable = false)
    private UUID producerProfileId;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @Column(name = "channel_name", nullable = false, length = 150)
    private String channelName;

    @Column(name = "description", nullable = true, columnDefinition = "text")
    private String description;

    @Column(name = "avatar_url", nullable = true, columnDefinition = "text")
    private String avatarUrl;

    @Column(name = "website_url", nullable = true, columnDefinition = "text")
    private String websiteUrl;

    @Column(name = "verification_status", nullable = false, length = 30)
    private String verificationStatus;

    public ProducerProfile() {
    }

    @PrePersist
    private void assignId() {
        if (producerProfileId == null) {
            producerProfileId = UUID.randomUUID();
        }
    }

    public UUID getProducerProfileId() {
        return producerProfileId;
    }

    public void setProducerProfileId(UUID producerProfileId) {
        this.producerProfileId = producerProfileId;
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

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getAvatarUrl() {
        return avatarUrl;
    }

    public void setAvatarUrl(String avatarUrl) {
        this.avatarUrl = avatarUrl;
    }

    public String getWebsiteUrl() {
        return websiteUrl;
    }

    public void setWebsiteUrl(String websiteUrl) {
        this.websiteUrl = websiteUrl;
    }

    public String getVerificationStatus() {
        return verificationStatus;
    }

    public void setVerificationStatus(String verificationStatus) {
        this.verificationStatus = verificationStatus;
    }

}
