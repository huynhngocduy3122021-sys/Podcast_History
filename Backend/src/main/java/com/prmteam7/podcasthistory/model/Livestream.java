package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "\"Livetream\"", indexes = {
        @Index(name = "idx_livestream_producer_profile_id", columnList = "producer_profile_id")
    })
public class Livestream extends UpdatedEntity {
    @Id
    @Column(name = "livestream_id", nullable = false, updatable = false)
    private UUID livestreamId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "producer_profile_id", nullable = false)
    private ProducerProfile producerProfile;

    @Column(name = "title", nullable = false, length = 220)
    private String title;

    @Column(name = "description", nullable = true, columnDefinition = "text")
    private String description;

    @Column(name = "stream_provider", nullable = false, length = 60)
    private String streamProvider;

    @Column(name = "stream_reference", nullable = true, length = 220)
    private String streamReference;

    @Column(name = "playback_url", nullable = true, columnDefinition = "text")
    private String playbackUrl;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    @Column(name = "scheduled_at", nullable = true)
    private Instant scheduledAt;

    @Column(name = "started_at", nullable = true)
    private Instant startedAt;

    @Column(name = "ended_at", nullable = true)
    private Instant endedAt;

    public Livestream() {
    }

    @PrePersist
    private void assignId() {
        if (livestreamId == null) {
            livestreamId = UUID.randomUUID();
        }
    }

    public UUID getLivestreamId() {
        return livestreamId;
    }

    public void setLivestreamId(UUID livestreamId) {
        this.livestreamId = livestreamId;
    }

    public ProducerProfile getProducerProfile() {
        return producerProfile;
    }

    public void setProducerProfile(ProducerProfile producerProfile) {
        this.producerProfile = producerProfile;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getStreamProvider() {
        return streamProvider;
    }

    public void setStreamProvider(String streamProvider) {
        this.streamProvider = streamProvider;
    }

    public String getStreamReference() {
        return streamReference;
    }

    public void setStreamReference(String streamReference) {
        this.streamReference = streamReference;
    }

    public String getPlaybackUrl() {
        return playbackUrl;
    }

    public void setPlaybackUrl(String playbackUrl) {
        this.playbackUrl = playbackUrl;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public Instant getScheduledAt() {
        return scheduledAt;
    }

    public void setScheduledAt(Instant scheduledAt) {
        this.scheduledAt = scheduledAt;
    }

    public Instant getStartedAt() {
        return startedAt;
    }

    public void setStartedAt(Instant startedAt) {
        this.startedAt = startedAt;
    }

    public Instant getEndedAt() {
        return endedAt;
    }

    public void setEndedAt(Instant endedAt) {
        this.endedAt = endedAt;
    }

}
