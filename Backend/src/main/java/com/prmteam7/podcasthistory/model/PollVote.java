package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "\"Poll_votes\"", uniqueConstraints = {
        @UniqueConstraint(name = "uk_poll_vote_user_id_poll_id", columnNames = {"user_id", "poll_id"})
    }, indexes = {
        @Index(name = "idx_poll_vote_poll_id", columnList = "poll_id"),
        @Index(name = "idx_poll_vote_poll_option_id", columnList = "poll_option_id"),
        @Index(name = "idx_poll_vote_user_id", columnList = "user_id"),
        @Index(name = "idx_poll_vote_poll_created", columnList = "poll_id, created_at DESC, poll_vote_id DESC")
    })
public class PollVote extends BaseEntity {
    @Id
    @Column(name = "poll_vote_id", nullable = false, updatable = false)
    private UUID pollVoteId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "poll_id", nullable = false)
    private Poll poll;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "poll_option_id", nullable = false)
    private PollOption pollOption;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    public PollVote() {
    }

    @PrePersist
    private void assignId() {
        if (pollVoteId == null) {
            pollVoteId = UUID.randomUUID();
        }
    }

    public UUID getPollVoteId() {
        return pollVoteId;
    }

    public void setPollVoteId(UUID pollVoteId) {
        this.pollVoteId = pollVoteId;
    }

    public Poll getPoll() {
        return poll;
    }

    public void setPoll(Poll poll) {
        this.poll = poll;
    }

    public PollOption getPollOption() {
        return pollOption;
    }

    public void setPollOption(PollOption pollOption) {
        this.pollOption = pollOption;
    }

    public AppUser getUser() {
        return user;
    }

    public void setUser(AppUser user) {
        this.user = user;
    }

}
