package com.prmteam7.podcasthistory.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.prmteam7.podcasthistory.model.Comment;

public interface CommentRepository extends JpaRepository<Comment, UUID> {

    @Query("""
            select comment from Comment comment
            where comment.podcast.podcastId = :podcastId
              and comment.deletedAt is null
              and upper(comment.status) in ('VISIBLE', 'APPROVED')
            order by comment.createdAt desc
            """)
    Page<Comment> findVisibleByPodcastId(@Param("podcastId") UUID podcastId, Pageable pageable);

    @Query("""
            select comment from Comment comment
            where comment.commentId = :commentId
              and comment.deletedAt is null
              and upper(comment.status) in ('VISIBLE', 'APPROVED')
            """)
    Optional<Comment> findVisibleById(@Param("commentId") UUID commentId);
}
