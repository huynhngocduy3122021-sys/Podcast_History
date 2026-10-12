package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "\"Listening_History\"", uniqueConstraints = {
        @UniqueConstraint(name = "uk_listening_history_user_id_podcast_id", columnNames = {"user_id", "podcast_id"})
    }, indexes = {
        @Index(name = "idx_listening_history_user_id", columnList = "user_id"),
        @Index(name = "idx_listening_history_podcast_id", columnList = "podcast_id")
    })
public class ListeningHistory extends UpdatedEntity {
    @Id
    @Column(name = "listening_history_id", nullable = false, updatable = false)
    private UUID listeningHistoryId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "podcast_id", nullable = false)
    private Podcast podcast;

    @Column(name = "progress_seconds", nullable = false)
    private Integer progressSeconds;

    @Column(name = "completed", nullable = false)
    private Boolean completed;

    @Column(name = "last_listened_at", nullable = false)
    private Instant lastListenedAt;

    public ListeningHistory() {
    }

    @PrePersist
    private void assignId() {
        if (listeningHistoryId == null) {
            listeningHistoryId = UUID.randomUUID();
        }
    }

    public UUID getListeningHistoryId() {
        return listeningHistoryId;
    }

    public void setListeningHistoryId(UUID listeningHistoryId) {
        this.listeningHistoryId = listeningHistoryId;
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

    public Integer getProgressSeconds() {
        return progressSeconds;
    }

    public void setProgressSeconds(Integer progressSeconds) {
        this.progressSeconds = progressSeconds;
    }

    public Boolean getCompleted() {
        return completed;
    }

    public void setCompleted(Boolean completed) {
        this.completed = completed;
    }

    public Instant getLastListenedAt() {
        return lastListenedAt;
    }

    public void setLastListenedAt(Instant lastListenedAt) {
        this.lastListenedAt = lastListenedAt;
    }

}
