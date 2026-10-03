package com.prmteam7.podcasthistory.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "conversation", uniqueConstraints = {
        @UniqueConstraint(name = "uk_conversation_user_id_producer_profile_id", columnNames = {"user_id", "producer_profile_id"})
    }, indexes = {
        @Index(name = "idx_conversation_user_id", columnList = "user_id"),
        @Index(name = "idx_conversation_producer_profile_id", columnList = "producer_profile_id")
    })
public class Conversation extends UpdatedEntity {
    @Id
    @Column(name = "conversation_id", nullable = false, updatable = false)
    private UUID conversationId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "producer_profile_id", nullable = false)
    private ProducerProfile producerProfile;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    @Column(name = "last_message_at", nullable = true)
    private Instant lastMessageAt;

    public Conversation() {
    }

    @PrePersist
    private void assignId() {
        if (conversationId == null) {
            conversationId = UUID.randomUUID();
        }
    }

    public UUID getConversationId() {
        return conversationId;
    }

    public void setConversationId(UUID conversationId) {
        this.conversationId = conversationId;
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

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public Instant getLastMessageAt() {
        return lastMessageAt;
    }

    public void setLastMessageAt(Instant lastMessageAt) {
        this.lastMessageAt = lastMessageAt;
    }

}
