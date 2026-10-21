package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.ColumnTransformer;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

@Entity
@Table(name = "\"Podcast_Transcript\"", uniqueConstraints = {
        @UniqueConstraint(name = "uq_podcast_transcript_media", columnNames = {"podcast_id", "media_key"})
}, indexes = {
        @Index(name = "idx_podcast_transcript_podcast_id", columnList = "podcast_id")
})
public class PodcastTranscript extends BaseEntity {
    private static final ObjectMapper JSON = new ObjectMapper();
    @Id
    @Column(name = "transcript_id", nullable = false, updatable = false)
    private UUID transcriptId;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "podcast_id", nullable = false)
    private Podcast podcast;
    @Column(name = "media_key", nullable = false, columnDefinition = "text")
    private String mediaKey;
    @Column(name = "status", nullable = false, length = 30)
    private String status = "PENDING";
    @Column(name = "language", length = 20)
    private String language;
    @Column(name = "model_name", nullable = false, length = 120)
    private String modelName = "faster-whisper-small";
    @Column(name = "full_text", columnDefinition = "text")
    private String fullText;
    @Column(name = "segments", columnDefinition = "jsonb")
    @ColumnTransformer(write = "?::jsonb")
    private String segments;
    @Column(name = "error_message", columnDefinition = "text")
    private String errorMessage;
    @Column(name = "processed_at")
    private Instant processedAt;
    @Column(name = "processing_started_at")
    private Instant processingStartedAt;

    @PrePersist
    private void assignId() {
        if (transcriptId == null) transcriptId = UUID.randomUUID();
    }
    public UUID getTranscriptId() { return transcriptId; }
    public Podcast getPodcast() { return podcast; }
    public void setPodcast(Podcast podcast) { this.podcast = podcast; }
    public String getMediaKey() { return mediaKey; }
    public void setMediaKey(String mediaKey) { this.mediaKey = mediaKey; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getLanguage() { return language; }
    public void setLanguage(String language) { this.language = language; }
    public String getModelName() { return modelName; }
    public void setModelName(String modelName) { this.modelName = modelName; }
    public String getFullText() { return fullText; }
    public void setFullText(String fullText) { this.fullText = fullText; }
    public JsonNode getSegments() {
        if (segments == null) return null;
        try {
            return JSON.readTree(segments);
        } catch (Exception exception) {
            throw new IllegalStateException("Transcript segments JSON không hợp lệ.", exception);
        }
    }
    public void setSegments(JsonNode segments) {
        this.segments = segments == null ? null : segments.toString();
    }
    public String getErrorMessage() { return errorMessage; }
    public void setErrorMessage(String errorMessage) { this.errorMessage = errorMessage; }
    public Instant getProcessedAt() { return processedAt; }
    public void setProcessedAt(Instant processedAt) { this.processedAt = processedAt; }
    public Instant getProcessingStartedAt() { return processingStartedAt; }
    public void setProcessingStartedAt(Instant processingStartedAt) { this.processingStartedAt = processingStartedAt; }
}
