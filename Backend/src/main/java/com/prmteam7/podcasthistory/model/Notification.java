package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.ColumnTransformer;

@Entity
@Table(name = "\"Notification\"", indexes = {
        @Index(name = "idx_notification_user_id", columnList = "user_id")
    })
public class Notification extends BaseEntity {
    private static final ObjectMapper JSON = new ObjectMapper();
    @Id
    @Column(name = "notification_id", nullable = false, updatable = false)
    private UUID notificationId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @Column(name = "notification_type", nullable = false, length = 40)
    private String notificationType;

    @Column(name = "title", nullable = false, length = 200)
    private String title;

    @Column(name = "message", nullable = false, columnDefinition = "text")
    private String message;

    @Column(name = "payload", nullable = true, columnDefinition = "jsonb")
    @ColumnTransformer(write = "?::jsonb")
    private String payload;

    @Column(name = "is_read", nullable = false)
    private Boolean isRead;

    @Column(name = "read_at", nullable = true)
    private Instant readAt;

    public Notification() {
    }

    @PrePersist
    private void assignId() {
        if (notificationId == null) {
            notificationId = UUID.randomUUID();
        }
    }

    public UUID getNotificationId() {
        return notificationId;
    }

    public void setNotificationId(UUID notificationId) {
        this.notificationId = notificationId;
    }

    public AppUser getUser() {
        return user;
    }

    public void setUser(AppUser user) {
        this.user = user;
    }

    public String getNotificationType() {
        return notificationType;
    }

    public void setNotificationType(String notificationType) {
        this.notificationType = notificationType;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public JsonNode getPayload() {
        if (payload == null) return null;
        try {
            return JSON.readTree(payload);
        } catch (Exception exception) {
            throw new IllegalStateException("Notification payload JSON không hợp lệ.", exception);
        }
    }

    public void setPayload(JsonNode payload) {
        this.payload = payload == null ? null : payload.toString();
    }

    public Boolean getIsRead() {
        return isRead;
    }

    public void setIsRead(Boolean isRead) {
        this.isRead = isRead;
    }

    public Instant getReadAt() {
        return readAt;
    }

    public void setReadAt(Instant readAt) {
        this.readAt = readAt;
    }

}
