package com.prmteam7.podcasthistory.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.ListeningHistory;

public interface ListeningHistoryRepository extends JpaRepository<ListeningHistory, UUID> {

    Optional<ListeningHistory> findByUser_UserIdAndPodcast_PodcastId(UUID userId, UUID podcastId);

    Page<ListeningHistory> findAllByUser_UserIdOrderByLastListenedAtDesc(UUID userId, Pageable pageable);
}
