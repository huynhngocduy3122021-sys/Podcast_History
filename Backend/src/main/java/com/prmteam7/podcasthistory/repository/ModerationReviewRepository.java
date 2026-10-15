package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.ModerationReview;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ModerationReviewRepository extends JpaRepository<ModerationReview, UUID> {
  @org.springframework.data.jpa.repository.EntityGraph(attributePaths = "reviewerUser")
  org.springframework.data.domain.Page<ModerationReview>
      findAllByPodcast_PodcastIdOrderByReviewedAtDesc(
          UUID podcastId, org.springframework.data.domain.Pageable page);

  @org.springframework.data.jpa.repository.EntityGraph(attributePaths = "reviewerUser")
  java.util.List<ModerationReview> findAllByReport_ReportIdOrderByReviewedAtDesc(UUID reportId);
}
