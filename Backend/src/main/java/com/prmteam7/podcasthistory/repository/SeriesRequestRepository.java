package com.prmteam7.podcasthistory.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.prmteam7.podcasthistory.model.SeriesRequest;

public interface SeriesRequestRepository extends JpaRepository<SeriesRequest, UUID> {

    List<SeriesRequest> findAllByUser_UserIdOrderByCreatedAtDesc(UUID userId);

    List<SeriesRequest> findAllByProducerProfile_User_UserIdAndStatusOrderByCreatedAtAsc(
            UUID creatorUserId, String status);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select request from SeriesRequest request where request.seriesRequestId = :requestId")
    Optional<SeriesRequest> findByIdForUpdate(@Param("requestId") UUID requestId);
}
