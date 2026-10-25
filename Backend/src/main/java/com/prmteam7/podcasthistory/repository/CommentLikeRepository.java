package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.CommentLike;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CommentLikeRepository extends JpaRepository<CommentLike, UUID> {
  boolean existsByUser_UserIdAndComment_CommentId(UUID userId, UUID commentId);

  long countByComment_CommentId(UUID commentId);

  Optional<CommentLike> findByUser_UserIdAndComment_CommentId(UUID userId, UUID commentId);

  @Query("""
      select cl.comment.commentId, count(cl) from CommentLike cl
      where cl.comment.commentId in :commentIds
      group by cl.comment.commentId
      """)
  List<Object[]> countByCommentIds(@Param("commentIds") List<UUID> commentIds);

  @Query("""
      select cl.comment.commentId from CommentLike cl
      where cl.user.userId = :userId and cl.comment.commentId in :commentIds
      """)
  List<UUID> likedCommentIds(@Param("userId") UUID userId,
      @Param("commentIds") List<UUID> commentIds);
}
