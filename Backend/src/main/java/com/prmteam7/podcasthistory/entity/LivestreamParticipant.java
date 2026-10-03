package com.prmteam7.podcasthistory.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "livestream_participant", indexes = {
        @Index(name = "idx_livestream_participant_livestream_id", columnList = "livestream_id"),
        @Index(name = "idx_livestream_participant_user_id", columnList = "user_id")
    })
public class LivestreamParticipant extends BaseEntity {
    @Id
    @Column(name = "livestream_participant_id", nullable = false, updatable = false)
    private UUID livestreamParticipantId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "livestream_id", nullable = false)
    private Livestream livestream;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @Column(name = "participant_role", nullable = false, length = 30)
    private String participantRole;

    @Column(name = "joined_at", nullable = false)
    private Instant joinedAt;

    @Column(name = "left_at", nullable = true)
    private Instant leftAt;

    public LivestreamParticipant() {
    }

    @PrePersist
    private void assignId() {
        if (livestreamParticipantId == null) {
            livestreamParticipantId = UUID.randomUUID();
        }
    }

    public UUID getLivestreamParticipantId() {
        return livestreamParticipantId;
    }

    public void setLivestreamParticipantId(UUID livestreamParticipantId) {
        this.livestreamParticipantId = livestreamParticipantId;
    }

    public Livestream getLivestream() {
        return livestream;
    }

    public void setLivestream(Livestream livestream) {
        this.livestream = livestream;
    }

    public AppUser getUser() {
        return user;
    }

    public void setUser(AppUser user) {
        this.user = user;
    }

    public String getParticipantRole() {
        return participantRole;
    }

    public void setParticipantRole(String participantRole) {
        this.participantRole = participantRole;
    }

    public Instant getJoinedAt() {
        return joinedAt;
    }

    public void setJoinedAt(Instant joinedAt) {
        this.joinedAt = joinedAt;
    }

    public Instant getLeftAt() {
        return leftAt;
    }

    public void setLeftAt(Instant leftAt) {
        this.leftAt = leftAt;
    }

}
