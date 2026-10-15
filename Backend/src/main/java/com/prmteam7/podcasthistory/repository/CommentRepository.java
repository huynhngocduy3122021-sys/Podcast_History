package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.Comment;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CommentRepository extends JpaRepository<Comment, UUID> {
  @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
  @Query("select c from Comment c where c.commentId=:id")
  Optional<Comment> lockById(@Param("id") UUID id);

  @Query(
      """
      select comment from Comment comment
      where comment.podcast.podcastId = :podcastId
        and comment.deletedAt is null
        and upper(comment.status) in ('VISIBLE', 'APPROVED')
      order by comment.createdAt desc, comment.commentId desc
      """)
  @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"user"})
  Page<Comment> findVisibleByPodcastId(@Param("podcastId") UUID podcastId, Pageable pageable);

  @Query(
      """
      select comment from Comment comment
      where comment.commentId = :commentId
        and comment.deletedAt is null
        and upper(comment.status) in ('VISIBLE', 'APPROVED')
      """)
  Optional<Comment> findVisibleById(@Param("commentId") UUID commentId);
}
