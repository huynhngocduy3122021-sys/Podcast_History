package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "\"Series\"", uniqueConstraints = {
        @UniqueConstraint(name = "uk_series_producer_profile_id_slug", columnNames = {"producer_profile_id", "slug"})
    }, indexes = {
        @Index(name = "idx_series_producer_profile_id", columnList = "producer_profile_id"),
        @Index(name = "idx_series_category_id", columnList = "category_id")
    })
public class Series extends UpdatedEntity {
    @Id
    @Column(name = "series_id", nullable = false, updatable = false)
    private UUID seriesId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "producer_profile_id", nullable = false)
    private ProducerProfile producerProfile;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "category_id", nullable = false)
    private Category category;

    @Column(name = "title", nullable = false, length = 200)
    private String title;

    @Column(name = "slug", nullable = false, length = 220)
    private String slug;

    @Column(name = "description", nullable = true, columnDefinition = "text")
    private String description;

    @Column(name = "cover_url", nullable = true, columnDefinition = "text")
    private String coverUrl;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    @Column(name = "published_at", nullable = true)
    private Instant publishedAt;

    public Series() {
    }

    @PrePersist
    private void assignId() {
        if (seriesId == null) {
            seriesId = UUID.randomUUID();
        }
    }

    public UUID getSeriesId() {
        return seriesId;
    }

    public void setSeriesId(UUID seriesId) {
        this.seriesId = seriesId;
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

    public String getCoverUrl() {
        return coverUrl;
    }

    public void setCoverUrl(String coverUrl) {
        this.coverUrl = coverUrl;
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
