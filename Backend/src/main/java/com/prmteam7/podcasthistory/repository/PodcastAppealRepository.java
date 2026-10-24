package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.PodcastAppeal;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.*;

public interface PodcastAppealRepository
    extends JpaRepository<PodcastAppeal, UUID>, JpaSpecificationExecutor<PodcastAppeal> {
  boolean existsByPodcast_PodcastIdAndStatus(UUID id, String status);

  @Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
  @Query("select a from PodcastAppeal a where a.appealId=:id")
  Optional<PodcastAppeal> lockById(@org.springframework.data.repository.query.Param("id") UUID id);
}
