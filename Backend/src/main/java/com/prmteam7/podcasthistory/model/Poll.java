package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "\"Polll\"", indexes = {
        @Index(name = "idx_poll_producer_profile_id", columnList = "producer_profile_id"),
        @Index(name = "idx_poll_series_id", columnList = "series_id"),
        @Index(name = "idx_poll_podcast_id", columnList = "podcast_id"),
        @Index(name = "idx_poll_creator_status_created", columnList = "producer_profile_id, status, created_at DESC, poll_id DESC")
    })
public class Poll extends UpdatedEntity {
    @Version
    @Column(name = "row_version", nullable = false, columnDefinition = "bigint default 0")
    private Long rowVersion = 0L;
    @Id
    @Column(name = "poll_id", nullable = false, updatable = false)
    private UUID pollId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "producer_profile_id", nullable = false)
    private ProducerProfile producerProfile;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "series_id", nullable = true)
    private Series series;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "podcast_id", nullable = true,
            foreignKey = @ForeignKey(name = "fk_poll_podcast"))
    private Podcast podcast;

    public Podcast getPodcast() {
        return podcast;
    }

    public void setPodcast(Podcast podcast) {
        this.podcast = podcast;
    }

    @Column(name = "question", nullable = false, columnDefinition = "text")
    private String question;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    @Column(name = "starts_at", nullable = false)
    private Instant startsAt;

    @Column(name = "ends_at", nullable = true)
    private Instant endsAt;

    public Poll() {
    }

    @PrePersist
    private void assignId() {
        if (pollId == null) {
            pollId = UUID.randomUUID();
        }
    }

    public UUID getPollId() {
        return pollId;
    }

    public void setPollId(UUID pollId) {
        this.pollId = pollId;
    }

    public ProducerProfile getProducerProfile() {
        return producerProfile;
    }

    public void setProducerProfile(ProducerProfile producerProfile) {
        this.producerProfile = producerProfile;
    }

    public Series getSeries() {
        return series;
    }

    public void setSeries(Series series) {
        this.series = series;
    }

    public String getQuestion() {
        return question;
    }

    public void setQuestion(String question) {
        this.question = question;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public Instant getStartsAt() {
        return startsAt;
    }

    public void setStartsAt(Instant startsAt) {
        this.startsAt = startsAt;
    }

    public Instant getEndsAt() {
        return endsAt;
    }

    public void setEndsAt(Instant endsAt) {
        this.endsAt = endsAt;
    }

}
