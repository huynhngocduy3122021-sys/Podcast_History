package com.prmteam7.podcasthistory.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "message", indexes = {
        @Index(name = "idx_message_conversation_id", columnList = "conversation_id"),
        @Index(name = "idx_message_user_id", columnList = "user_id")
    })
public class Message extends BaseEntity {
    @Id
    @Column(name = "message_id", nullable = false, updatable = false)
    private UUID messageId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "conversation_id", nullable = false)
    private Conversation conversation;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @Column(name = "content", nullable = false, columnDefinition = "text")
    private String content;

    @Column(name = "message_type", nullable = false, length = 30)
    private String messageType;

    @Column(name = "attachment_url", nullable = true, columnDefinition = "text")
    private String attachmentUrl;

    @Column(name = "sent_at", nullable = false)
    private Instant sentAt;

    @Column(name = "read_at", nullable = true)
    private Instant readAt;

    public Message() {
    }

    @PrePersist
    private void assignId() {
        if (messageId == null) {
            messageId = UUID.randomUUID();
        }
    }

    public UUID getMessageId() {
        return messageId;
    }

    public void setMessageId(UUID messageId) {
        this.messageId = messageId;
    }

    public Conversation getConversation() {
        return conversation;
    }

    public void setConversation(Conversation conversation) {
        this.conversation = conversation;
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

    public String getMessageType() {
        return messageType;
    }

    public void setMessageType(String messageType) {
        this.messageType = messageType;
    }

    public String getAttachmentUrl() {
        return attachmentUrl;
    }

    public void setAttachmentUrl(String attachmentUrl) {
        this.attachmentUrl = attachmentUrl;
    }

    public Instant getSentAt() {
        return sentAt;
    }

    public void setSentAt(Instant sentAt) {
        this.sentAt = sentAt;
    }

    public Instant getReadAt() {
        return readAt;
    }

    public void setReadAt(Instant readAt) {
        this.readAt = readAt;
    }

}
