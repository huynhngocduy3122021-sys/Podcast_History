package com.prmteam7.podcasthistory.entity;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "podcast_like", uniqueConstraints = {
        @UniqueConstraint(name = "uk_podcast_like_user_id_podcast_id", columnNames = {"user_id", "podcast_id"})
    }, indexes = {
        @Index(name = "idx_podcast_like_user_id", columnList = "user_id"),
        @Index(name = "idx_podcast_like_podcast_id", columnList = "podcast_id")
    })
public class PodcastLike extends BaseEntity {
    @Id
    @Column(name = "podcast_like_id", nullable = false, updatable = false)
    private UUID podcastLikeId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "podcast_id", nullable = false)
    private Podcast podcast;

    public PodcastLike() {
    }

    @PrePersist
    private void assignId() {
        if (podcastLikeId == null) {
            podcastLikeId = UUID.randomUUID();
        }
    }

    public UUID getPodcastLikeId() {
        return podcastLikeId;
    }

    public void setPodcastLikeId(UUID podcastLikeId) {
        this.podcastLikeId = podcastLikeId;
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
