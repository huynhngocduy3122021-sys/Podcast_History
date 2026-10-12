package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "\"Follow\"", uniqueConstraints = {
        @UniqueConstraint(name = "uk_follow_user_id_producer_profile_id", columnNames = {"user_id", "producer_profile_id"})
    }, indexes = {
        @Index(name = "idx_follow_user_id", columnList = "user_id"),
        @Index(name = "idx_follow_producer_profile_id", columnList = "producer_profile_id")
    })
public class Follow extends BaseEntity {
    @Id
    @Column(name = "follow_id", nullable = false, updatable = false)
    private UUID followId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "producer_profile_id", nullable = false)
    private ProducerProfile producerProfile;

    public Follow() {
    }

    @PrePersist
    private void assignId() {
        if (followId == null) {
            followId = UUID.randomUUID();
        }
    }

    public UUID getFollowId() {
        return followId;
    }

    public void setFollowId(UUID followId) {
        this.followId = followId;
    }

    public AppUser getUser() {
        return user;
    }

    public void setUser(AppUser user) {
        this.user = user;
    }

    public ProducerProfile getProducerProfile() {
        return producerProfile;
    }

    public void setProducerProfile(ProducerProfile producerProfile) {
        this.producerProfile = producerProfile;
    }

}
