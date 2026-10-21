package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import tools.jackson.databind.JsonNode;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.ColumnTransformer;
import tools.jackson.databind.ObjectMapper;

@Entity
@Table(name = "\"AI_Moderation_Result\"", indexes = {
        @Index(name = "idx_ai_moderation_result_podcast_id", columnList = "podcast_id")
    })
public class AiModerationResult extends BaseEntity {
    private static final ObjectMapper JSON = new ObjectMapper();
    @Id
    @Column(name = "moderation_result_id", nullable = false, updatable = false)
    private UUID moderationResultId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "podcast_id", nullable = false)
    private Podcast podcast;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "transcript_id")
    private PodcastTranscript transcript;

    @Column(name = "transcript_hash", length = 64)
    private String transcriptHash;

    @Column(name = "model_name", nullable = false, length = 120)
    private String modelName;

    @Column(name = "model_version", nullable = true, length = 60)
    private String modelVersion;

    @Column(name = "overall_label", nullable = false, length = 40)
    private String overallLabel;

    @Column(name = "confidence_score", nullable = true, precision = 5, scale = 4)
    private BigDecimal confidenceScore;

    @Column(name = "raw_result", nullable = true, columnDefinition = "jsonb")
    @ColumnTransformer(write = "?::jsonb")
    private String rawResult;

    @Column(name = "processed_at")
    private Instant processedAt;

    @Column(name = "status", nullable = false, length = 30)
    private String status = "PENDING";

    @Column(name = "recommendation", length = 30)
    private String recommendation;

    @Column(name = "reason", columnDefinition = "text")
    private String reason;

    @Column(name = "source_hash", length = 64)
    private String sourceHash;

    @Column(name = "media_key", columnDefinition = "text")
    private String mediaKey;

    @Column(name = "error_message", columnDefinition = "text")
    private String errorMessage;

    public AiModerationResult() {
    }

    @PrePersist
    private void assignId() {
        if (moderationResultId == null) {
            moderationResultId = UUID.randomUUID();
        }
    }

    public UUID getModerationResultId() {
        return moderationResultId;
    }

    public void setModerationResultId(UUID moderationResultId) {
        this.moderationResultId = moderationResultId;
    }

    public Podcast getPodcast() {
        return podcast;
    }

    public void setPodcast(Podcast podcast) {
        this.podcast = podcast;
    }

    public PodcastTranscript getTranscript() { return transcript; }

    public void setTranscript(PodcastTranscript transcript) { this.transcript = transcript; }

    public String getTranscriptHash() { return transcriptHash; }

    public void setTranscriptHash(String transcriptHash) { this.transcriptHash = transcriptHash; }

    public String getModelName() {
        return modelName;
    }

    public void setModelName(String modelName) {
        this.modelName = modelName;
    }

    public String getModelVersion() {
        return modelVersion;
    }

    public void setModelVersion(String modelVersion) {
        this.modelVersion = modelVersion;
    }

    public String getOverallLabel() {
        return overallLabel;
    }

    public void setOverallLabel(String overallLabel) {
        this.overallLabel = overallLabel;
    }

    public BigDecimal getConfidenceScore() {
        return confidenceScore;
    }

    public void setConfidenceScore(BigDecimal confidenceScore) {
        this.confidenceScore = confidenceScore;
    }

    public JsonNode getRawResult() {
        if (rawResult == null) return null;
        try {
            return JSON.readTree(rawResult);
        } catch (Exception exception) {
            throw new IllegalStateException("AI raw result JSON không hợp lệ.", exception);
        }
    }

    public void setRawResult(JsonNode rawResult) {
        this.rawResult = rawResult == null ? null : rawResult.toString();
    }

    public Instant getProcessedAt() {
        return processedAt;
    }

    public void setProcessedAt(Instant processedAt) {
        this.processedAt = processedAt;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getRecommendation() {
        return recommendation;
    }

    public void setRecommendation(String recommendation) {
        this.recommendation = recommendation;
    }

    public String getReason() {
        return reason;
    }

    public void setReason(String reason) {
        this.reason = reason;
    }

    public String getSourceHash() {
        return sourceHash;
    }

    public void setSourceHash(String sourceHash) {
        this.sourceHash = sourceHash;
    }

    public String getMediaKey() {
        return mediaKey;
    }

    public void setMediaKey(String mediaKey) {
        this.mediaKey = mediaKey;
    }

    public String getErrorMessage() {
        return errorMessage;
    }

    public void setErrorMessage(String errorMessage) {
        this.errorMessage = errorMessage;
    }

}
