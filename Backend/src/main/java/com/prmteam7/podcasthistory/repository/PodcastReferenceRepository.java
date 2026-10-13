package com.prmteam7.podcasthistory.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import com.prmteam7.podcasthistory.model.PodcastReference;

public interface PodcastReferenceRepository extends JpaRepository<PodcastReference, UUID> {
    List<PodcastReference> findAllByPodcast_PodcastIdOrderByCreatedAtAsc(UUID podcastId);
    Optional<PodcastReference> findByReferenceIdAndPodcast_PodcastId(UUID referenceId, UUID podcastId);
}
