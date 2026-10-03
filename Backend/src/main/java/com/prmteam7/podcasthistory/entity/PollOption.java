package com.prmteam7.podcasthistory.entity;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "poll_option", indexes = {
        @Index(name = "idx_poll_option_poll_id", columnList = "poll_id")
    })
public class PollOption extends BaseEntity {
    @Id
    @Column(name = "poll_option_id", nullable = false, updatable = false)
    private UUID pollOptionId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "poll_id", nullable = false)
    private Poll poll;

    @Column(name = "option_text", nullable = false, length = 300)
    private String optionText;

    @Column(name = "sort_order", nullable = false)
    private Integer sortOrder;

    public PollOption() {
    }

    @PrePersist
    private void assignId() {
        if (pollOptionId == null) {
            pollOptionId = UUID.randomUUID();
        }
    }

    public UUID getPollOptionId() {
        return pollOptionId;
    }

    public void setPollOptionId(UUID pollOptionId) {
        this.pollOptionId = pollOptionId;
    }

    public Poll getPoll() {
        return poll;
    }

    public void setPoll(Poll poll) {
        this.poll = poll;
    }

    public String getOptionText() {
        return optionText;
    }

    public void setOptionText(String optionText) {
        this.optionText = optionText;
    }

    public Integer getSortOrder() {
        return sortOrder;
    }

    public void setSortOrder(Integer sortOrder) {
        this.sortOrder = sortOrder;
    }

}
