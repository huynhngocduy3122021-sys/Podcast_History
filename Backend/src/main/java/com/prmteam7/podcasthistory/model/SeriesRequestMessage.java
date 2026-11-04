package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "series_request_message", indexes = {
        @Index(name = "idx_series_request_message_request", columnList = "series_request_id,created_at")
})
public class SeriesRequestMessage extends BaseEntity {
    @Id
    @Column(name = "message_id", nullable = false, updatable = false)
    private UUID messageId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "series_request_id", nullable = false)
    private SeriesRequest seriesRequest;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "sender_id", nullable = false)
    private AppUser sender;

    @Column(name = "content", nullable = false, columnDefinition = "text")
    private String content;

    @PrePersist
    private void assignId() {
        if (messageId == null) messageId = UUID.randomUUID();
    }

    public UUID getMessageId() { return messageId; }
    public SeriesRequest getSeriesRequest() { return seriesRequest; }
    public void setSeriesRequest(SeriesRequest seriesRequest) { this.seriesRequest = seriesRequest; }
    public AppUser getSender() { return sender; }
    public void setSender(AppUser sender) { this.sender = sender; }
    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }
}
