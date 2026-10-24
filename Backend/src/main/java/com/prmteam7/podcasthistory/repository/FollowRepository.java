package com.prmteam7.podcasthistory.repository;

import java.util.Optional;
import java.util.UUID;
import java.util.List;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.repository.query.Param;

import com.prmteam7.podcasthistory.model.Follow;
import com.prmteam7.podcasthistory.model.AppUser;

public interface FollowRepository extends JpaRepository<Follow, UUID> {

    long countByProducerProfile_ProducerProfileId(UUID creatorId);

    Optional<Follow> findByUser_UserIdAndProducerProfile_ProducerProfileId(UUID userId, UUID creatorId);

    @org.springframework.data.jpa.repository.Query("""
        select follow.user from Follow follow
        where follow.producerProfile.producerProfileId = :creatorId
          and follow.user.isActive = true
          and follow.user.role.roleCode = 'LISTENER'
        """)
    List<AppUser> findActiveListenersByCreatorId(@Param("creatorId") UUID creatorId);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"producerProfile"})
    Page<Follow> findAllByUser_UserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);
}
