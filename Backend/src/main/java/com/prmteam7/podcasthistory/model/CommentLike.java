package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "\"Comment_like\"", uniqueConstraints = {
    @UniqueConstraint(name = "uk_comment_like_user_id_comment_id", columnNames = {"user_id", "comment_id"})
}, indexes = {
    @Index(name = "idx_comment_like_user_id", columnList = "user_id"),
    @Index(name = "idx_comment_like_comment_id", columnList = "comment_id")
})
public class CommentLike extends BaseEntity {
  @Id
  @Column(name = "comment_like_id", nullable = false, updatable = false)
  private UUID commentLikeId;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "user_id", nullable = false)
  private AppUser user;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "comment_id", nullable = false)
  private Comment comment;

  @PrePersist
  private void assignId() {
    if (commentLikeId == null) commentLikeId = UUID.randomUUID();
  }

  public UUID getCommentLikeId() { return commentLikeId; }
  public AppUser getUser() { return user; }
  public void setUser(AppUser user) { this.user = user; }
  public Comment getComment() { return comment; }
  public void setComment(Comment comment) { this.comment = comment; }
}
