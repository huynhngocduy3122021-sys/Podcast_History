package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "\"Podcast\"", uniqueConstraints = {
        @UniqueConstraint(name = "uk_podcast_series_id_slug", columnNames = {"series_id", "slug"})
    }, indexes = {
        @Index(name = "idx_podcast_series_id", columnList = "series_id"),
        @Index(name = "idx_podcast_producer_profile_id", columnList = "producer_profile_id"),
        @Index(name = "idx_podcast_category_id", columnList = "category_id")
    })
public class Podcast extends UpdatedEntity {
    @Id
    @Column(name = "podcast_id", nullable = false, updatable = false)
    private UUID podcastId;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "series_id", nullable = true)
    private Series series;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "producer_profile_id", nullable = false)
    private ProducerProfile producerProfile;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "category_id", nullable = false)
    private Category category;

    @Column(name = "title", nullable = false, length = 220)
    private String title;

    @Column(name = "slug", nullable = false, length = 240)
    private String slug;

    @Column(name = "description", nullable = true, columnDefinition = "text")
    private String description;

    @Column(name = "media_url", nullable = true, columnDefinition = "text")
    private String mediaUrl;

    @Column(name = "media_type", nullable = true, length = 20)
    private String mediaType;

    @Column(name = "thumbnail_url", nullable = true, columnDefinition = "text")
    private String thumbnailUrl;

    @Column(name = "duration_seconds", nullable = false)
    private Integer durationSeconds;

    @Column(name = "episode_number", nullable = true)
    private Integer episodeNumber;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    @Column(name = "is_exclusive", nullable = false)
    private Boolean isExclusive = false;

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

    public ProducerProfile getProducerProfile() {
        return producerProfile;
    }

    public void setProducerProfile(ProducerProfile producerProfile) {
        this.producerProfile = producerProfile;
    }

    public Category getCategory() {
        return category;
    }

    public void setCategory(Category category) {
        this.category = category;
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

    public Boolean getIsExclusive() {
        return isExclusive;
    }

    public void setIsExclusive(Boolean isExclusive) {
        this.isExclusive = isExclusive;
    }

    public Instant getPublishedAt() {
        return publishedAt;
    }

    public void setPublishedAt(Instant publishedAt) {
        this.publishedAt = publishedAt;
    }

}
