package com.prmteam7.podcasthistory.entity;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "saved_podcast", uniqueConstraints = {
        @UniqueConstraint(name = "uk_saved_podcast_user_id_podcast_id", columnNames = {"user_id", "podcast_id"})
    }, indexes = {
        @Index(name = "idx_saved_podcast_user_id", columnList = "user_id"),
        @Index(name = "idx_saved_podcast_podcast_id", columnList = "podcast_id")
    })
public class SavedPodcast extends BaseEntity {
    @Id
    @Column(name = "saved_podcast_id", nullable = false, updatable = false)
    private UUID savedPodcastId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "podcast_id", nullable = false)
    private Podcast podcast;

    public SavedPodcast() {
    }

    @PrePersist
    private void assignId() {
        if (savedPodcastId == null) {
            savedPodcastId = UUID.randomUUID();
        }
    }

    public UUID getSavedPodcastId() {
        return savedPodcastId;
    }

    public void setSavedPodcastId(UUID savedPodcastId) {
        this.savedPodcastId = savedPodcastId;
    }

    public AppUser getUser() {
        return user;
    }

    public void setUser(AppUser user) {
        this.user = user;
    }

    public Podcast getPodcast() {
        return podcast;
    }

    public void setPodcast(Podcast podcast) {
        this.podcast = podcast;
    }

}
