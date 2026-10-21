package com.prmteam7.podcasthistory.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.Follow;

public interface FollowRepository extends JpaRepository<Follow, UUID> {

    long countByProducerProfile_ProducerProfileId(UUID creatorId);

    Optional<Follow> findByUser_UserIdAndProducerProfile_ProducerProfileId(UUID userId, UUID creatorId);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"producerProfile"})
    Page<Follow> findAllByUser_UserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);
}
