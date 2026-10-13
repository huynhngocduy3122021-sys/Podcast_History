package com.prmteam7.podcasthistory.repository;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.SeriesRequest;

public interface SeriesRequestRepository extends JpaRepository<SeriesRequest, UUID> {

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"producerProfile"})
    List<SeriesRequest> findAllByUser_UserIdOrderByCreatedAtDesc(UUID userId);
}
