package com.prmteam7.podcasthistory.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.Check;

@Entity
@Table(name = "report", indexes = {
        @Index(name = "idx_report_user_id", columnList = "user_id"),
        @Index(name = "idx_report_podcast_id", columnList = "podcast_id"),
        @Index(name = "idx_report_comment_id", columnList = "comment_id"),
        @Index(name = "idx_report_message_id", columnList = "message_id"),
        @Index(name = "idx_report_livestream_id", columnList = "livestream_id")
    })
@Check(constraints = "num_nonnulls(podcast_id, comment_id, message_id, livestream_id) = 1")
public class Report extends BaseEntity {
    @Id
    @Column(name = "report_id", nullable = false, updatable = false)
    private UUID reportId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "podcast_id", nullable = true)
    private Podcast podcast;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "comment_id", nullable = true)
    private Comment comment;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "message_id", nullable = true)
    private Message message;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "livestream_id", nullable = true)
    private Livestream livestream;

    @Column(name = "reason_code", nullable = false, length = 50)
    private String reasonCode;

    @Column(name = "description", nullable = true, columnDefinition = "text")
    private String description;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    @Column(name = "resolved_at", nullable = true)
    private Instant resolvedAt;

    public Report() {
    }

    @PrePersist
    private void assignId() {
        if (reportId == null) {
            reportId = UUID.randomUUID();
        }
    }

    public UUID getReportId() {
        return reportId;
    }

    public void setReportId(UUID reportId) {
        this.reportId = reportId;
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

    public Comment getComment() {
        return comment;
    }

    public void setComment(Comment comment) {
        this.comment = comment;
    }

    public Message getMessage() {
        return message;
    }

    public void setMessage(Message message) {
        this.message = message;
    }

    public Livestream getLivestream() {
        return livestream;
    }

    public void setLivestream(Livestream livestream) {
        this.livestream = livestream;
    }

    public String getReasonCode() {
        return reasonCode;
    }

    public void setReasonCode(String reasonCode) {
        this.reasonCode = reasonCode;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public Instant getResolvedAt() {
        return resolvedAt;
    }

    public void setResolvedAt(Instant resolvedAt) {
        this.resolvedAt = resolvedAt;
    }

}
