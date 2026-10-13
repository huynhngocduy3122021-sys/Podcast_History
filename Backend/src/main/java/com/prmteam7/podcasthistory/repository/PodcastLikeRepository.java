package com.prmteam7.podcasthistory.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.PodcastLike;

public interface PodcastLikeRepository extends JpaRepository<PodcastLike, UUID> {

    boolean existsByUser_UserIdAndPodcast_PodcastId(UUID userId, UUID podcastId);

    long countByPodcast_PodcastId(UUID podcastId);

    long countByPodcast_PodcastIdAndUser_UserId(UUID podcastId, UUID userId);

    Optional<PodcastLike> findByUser_UserIdAndPodcast_PodcastId(UUID userId, UUID podcastId);
}
