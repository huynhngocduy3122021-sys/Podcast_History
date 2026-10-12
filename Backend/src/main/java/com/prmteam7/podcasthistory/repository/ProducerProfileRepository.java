package com.prmteam7.podcasthistory.repository;

import java.util.UUID;
import java.util.List;
import java.util.Optional;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.prmteam7.podcasthistory.model.ProducerProfile;

public interface ProducerProfileRepository extends JpaRepository<ProducerProfile, UUID> {

    boolean existsByChannelNameIgnoreCase(String channelName);

    boolean existsByUser_UserId(UUID userId);

    boolean existsByChannelNameIgnoreCaseAndProducerProfileIdNot(String channelName, UUID producerProfileId);

    @EntityGraph(attributePaths = "user")
    Optional<ProducerProfile> findByUser_UserId(UUID userId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            select profile
            from ProducerProfile profile
            join fetch profile.user
            where profile.user.userId = :userId
            """)
    Optional<ProducerProfile> findByUserIdForUpdate(@Param("userId") UUID userId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            select profile
            from ProducerProfile profile
            join fetch profile.user
            where profile.producerProfileId = :profileId
            """)
    Optional<ProducerProfile> findByIdForUpdate(@Param("profileId") UUID profileId);

    List<ProducerProfile> findAllByVerificationStatusIgnoreCaseOrderByChannelNameAsc(String verificationStatus);
}
