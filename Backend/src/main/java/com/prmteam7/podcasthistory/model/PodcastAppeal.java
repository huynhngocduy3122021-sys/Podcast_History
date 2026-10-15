package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(
    name = "\"Podcast_appeal\"",
    indexes = {@Index(name = "idx_podcast_appeal_status", columnList = "status,created_at")})
public class PodcastAppeal extends BaseEntity {
  @Id
  @Column(name = "appeal_id")
  private UUID appealId;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "podcast_id")
  private Podcast podcast;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "applicant_id")
  private AppUser applicant;

  @Column(nullable = false, columnDefinition = "text")
  private String reason;

  @Column(nullable = false, length = 30)
  private String status;

  @Column(columnDefinition = "text")
  private String note;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "reviewer_id")
  private AppUser reviewer;

  @Column(name = "resolved_at")
  private Instant resolvedAt;

  @PrePersist
  void assignId() {
    if (appealId == null) appealId = UUID.randomUUID();
  }

  public UUID getAppealId() {
    return appealId;
  }

  public Podcast getPodcast() {
    return podcast;
  }

  public void setPodcast(Podcast v) {
    podcast = v;
  }

  public AppUser getApplicant() {
    return applicant;
  }

  public void setApplicant(AppUser v) {
    applicant = v;
  }

  public String getReason() {
    return reason;
  }

  public void setReason(String v) {
    reason = v;
  }

  public String getStatus() {
    return status;
  }

  public void setStatus(String v) {
    status = v;
  }

  public String getNote() {
    return note;
  }

  public void setNote(String v) {
    note = v;
  }

  public AppUser getReviewer() {
    return reviewer;
  }

  public void setReviewer(AppUser v) {
    reviewer = v;
  }

  public Instant getResolvedAt() {
    return resolvedAt;
  }

  public void setResolvedAt(Instant v) {
    resolvedAt = v;
  }
}
