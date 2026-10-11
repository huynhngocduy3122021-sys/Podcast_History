package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "live_chat_message", indexes = {
        @Index(name = "idx_live_chat_message_livestream_id", columnList = "livestream_id"),
        @Index(name = "idx_live_chat_message_user_id", columnList = "user_id")
    })
public class LiveChatMessage extends BaseEntity {
    @Id
    @Column(name = "live_chat_message_id", nullable = false, updatable = false)
    private UUID liveChatMessageId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "livestream_id", nullable = false)
    private Livestream livestream;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @Column(name = "content", nullable = false, columnDefinition = "text")
    private String content;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    @Column(name = "sent_at", nullable = false)
    private Instant sentAt;

    public LiveChatMessage() {
    }

    @PrePersist
    private void assignId() {
        if (liveChatMessageId == null) {
            liveChatMessageId = UUID.randomUUID();
        }
    }

    public UUID getLiveChatMessageId() {
        return liveChatMessageId;
    }

    public void setLiveChatMessageId(UUID liveChatMessageId) {
        this.liveChatMessageId = liveChatMessageId;
    }

    public Livestream getLivestream() {
        return livestream;
    }

    public void setLivestream(Livestream livestream) {
        this.livestream = livestream;
    }

    public AppUser getUser() {
        return user;
    }

    public void setUser(AppUser user) {
        this.user = user;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public Instant getSentAt() {
        return sentAt;
    }

    public void setSentAt(Instant sentAt) {
        this.sentAt = sentAt;
    }

}
