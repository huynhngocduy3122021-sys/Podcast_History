package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.SeriesRequestMessage;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SeriesRequestMessageRepository extends JpaRepository<SeriesRequestMessage, UUID> {
    List<SeriesRequestMessage> findAllBySeriesRequest_SeriesRequestIdOrderByCreatedAtAsc(UUID requestId);
}
