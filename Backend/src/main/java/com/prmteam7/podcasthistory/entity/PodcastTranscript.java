package com.prmteam7.podcasthistory.entity;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "podcast_transcript", indexes = {
        @Index(name = "idx_podcast_transcript_podcast_id", columnList = "podcast_id")
    })
public class PodcastTranscript extends UpdatedEntity {
    @Id
    @Column(name = "transcript_id", nullable = false, updatable = false)
    private UUID transcriptId;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "podcast_id", nullable = false)
    private Podcast podcast;

    @Column(name = "language_code", nullable = false, length = 10)
    private String languageCode;

    @Column(name = "transcript_text", nullable = false, columnDefinition = "text")
    private String transcriptText;

    @Column(name = "source_type", nullable = false, length = 30)
    private String sourceType;

    @Column(name = "version", nullable = false)
    private Integer version;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    public PodcastTranscript() {
    }

    @PrePersist
    private void assignId() {
        if (transcriptId == null) {
            transcriptId = UUID.randomUUID();
        }
    }

    public UUID getTranscriptId() {
        return transcriptId;
    }

    public void setTranscriptId(UUID transcriptId) {
        this.transcriptId = transcriptId;
    }

    public Podcast getPodcast() {
        return podcast;
    }

    public void setPodcast(Podcast podcast) {
        this.podcast = podcast;
    }

    public String getLanguageCode() {
        return languageCode;
    }

    public void setLanguageCode(String languageCode) {
        this.languageCode = languageCode;
    }

    public String getTranscriptText() {
        return transcriptText;
    }

    public void setTranscriptText(String transcriptText) {
        this.transcriptText = transcriptText;
    }

    public String getSourceType() {
        return sourceType;
    }

    public void setSourceType(String sourceType) {
        this.sourceType = sourceType;
    }

    public Integer getVersion() {
        return version;
    }

    public void setVersion(Integer version) {
        this.version = version;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

}
