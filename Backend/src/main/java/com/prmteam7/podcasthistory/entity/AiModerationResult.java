package com.prmteam7.podcasthistory.entity;

import jakarta.persistence.*;
import tools.jackson.databind.JsonNode;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "ai_moderation_result", indexes = {
        @Index(name = "idx_ai_moderation_result_podcast_id", columnList = "podcast_id")
    })
public class AiModerationResult extends BaseEntity {
    @Id
    @Column(name = "moderation_result_id", nullable = false, updatable = false)
    private UUID moderationResultId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "podcast_id", nullable = false)
    private Podcast podcast;

    @Column(name = "model_name", nullable = false, length = 120)
    private String modelName;

    @Column(name = "model_version", nullable = true, length = 60)
    private String modelVersion;

    @Column(name = "overall_label", nullable = false, length = 40)
    private String overallLabel;

    @Column(name = "confidence_score", nullable = true, precision = 5, scale = 4)
    private BigDecimal confidenceScore;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "raw_result", nullable = true, columnDefinition = "jsonb")
    private JsonNode rawResult;

    @Column(name = "processed_at", nullable = false)
    private Instant processedAt;

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
        return rawResult;
    }

    public void setRawResult(JsonNode rawResult) {
        this.rawResult = rawResult;
    }

    public Instant getProcessedAt() {
        return processedAt;
    }

    public void setProcessedAt(Instant processedAt) {
        this.processedAt = processedAt;
    }

}
