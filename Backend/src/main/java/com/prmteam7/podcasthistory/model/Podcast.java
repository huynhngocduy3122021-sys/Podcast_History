package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "\"Podcast\"", uniqueConstraints = {
        @UniqueConstraint(name = "uk_podcast_series_id_slug", columnNames = {"series_id", "slug"})
    }, indexes = {
        @Index(name = "idx_podcast_series_id", columnList = "series_id")
    })
public class Podcast extends UpdatedEntity {
    @Id
    @Column(name = "podcast_id", nullable = false, updatable = false)
    private UUID podcastId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "series_id", nullable = false)
    private Series series;

    @Column(name = "title", nullable = false, length = 220)
    private String title;

    @Column(name = "slug", nullable = false, length = 240)
    private String slug;

    @Column(name = "description", nullable = true, columnDefinition = "text")
    private String description;

    @Column(name = "media_url", nullable = false, columnDefinition = "text")
    private String mediaUrl;

    @Column(name = "media_type", nullable = false, length = 20)
    private String mediaType;

    @Column(name = "thumbnail_url", nullable = true, columnDefinition = "text")
    private String thumbnailUrl;

    @Column(name = "duration_seconds", nullable = false)
    private Integer durationSeconds;

    @Column(name = "episode_number", nullable = true)
    private Integer episodeNumber;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    @Column(name = "published_at", nullable = true)
    private Instant publishedAt;

    public Podcast() {
    }

    @PrePersist
    private void assignId() {
        if (podcastId == null) {
            podcastId = UUID.randomUUID();
        }
    }

    public UUID getPodcastId() {
        return podcastId;
    }

    public void setPodcastId(UUID podcastId) {
        this.podcastId = podcastId;
    }

    public Series getSeries() {
        return series;
    }

    public void setSeries(Series series) {
        this.series = series;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getSlug() {
        return slug;
    }

    public void setSlug(String slug) {
        this.slug = slug;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getMediaUrl() {
        return mediaUrl;
    }

    public void setMediaUrl(String mediaUrl) {
        this.mediaUrl = mediaUrl;
    }

    public String getMediaType() {
        return mediaType;
    }

    public void setMediaType(String mediaType) {
        this.mediaType = mediaType;
    }

    public String getThumbnailUrl() {
        return thumbnailUrl;
    }

    public void setThumbnailUrl(String thumbnailUrl) {
        this.thumbnailUrl = thumbnailUrl;
    }

    public Integer getDurationSeconds() {
        return durationSeconds;
    }

    public void setDurationSeconds(Integer durationSeconds) {
        this.durationSeconds = durationSeconds;
    }

    public Integer getEpisodeNumber() {
        return episodeNumber;
    }

    public void setEpisodeNumber(Integer episodeNumber) {
        this.episodeNumber = episodeNumber;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public Instant getPublishedAt() {
        return publishedAt;
    }

    public void setPublishedAt(Instant publishedAt) {
        this.publishedAt = publishedAt;
    }

}
