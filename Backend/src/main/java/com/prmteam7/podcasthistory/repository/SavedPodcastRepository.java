package com.prmteam7.podcasthistory.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.SavedPodcast;

public interface SavedPodcastRepository extends JpaRepository<SavedPodcast, UUID> {

    Optional<SavedPodcast> findByUser_UserIdAndPodcast_PodcastId(UUID userId, UUID podcastId);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"podcast", "podcast.producerProfile"})
    Page<SavedPodcast> findAllByUser_UserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);
}
