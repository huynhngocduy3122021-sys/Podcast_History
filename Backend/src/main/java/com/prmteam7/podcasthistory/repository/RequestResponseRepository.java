package com.prmteam7.podcasthistory.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.RequestResponse;

public interface RequestResponseRepository extends JpaRepository<RequestResponse, UUID> {

    Optional<RequestResponse> findTopBySeriesRequest_SeriesRequestIdOrderByCreatedAtDesc(UUID seriesRequestId);
}
