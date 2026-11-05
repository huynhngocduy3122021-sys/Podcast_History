package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.Livestream;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;
import java.util.Optional;

public interface LivestreamRepository extends JpaRepository<Livestream, UUID> {
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select live from Livestream live where live.livestreamId = :id")
  Optional<Livestream> lockById(@Param("id") UUID id);

  boolean existsByProducerProfile_ProducerProfileIdAndStatusIgnoreCase(UUID creatorId, String status);

  @EntityGraph(attributePaths = {"producerProfile"})
  List<Livestream> findAllByProducerProfile_ProducerProfileIdOrderByCreatedAtDesc(UUID creatorId);

  @EntityGraph(attributePaths = {"producerProfile"})
  Page<Livestream> findAllByStatusIgnoreCaseAndProducerProfile_VerificationStatusIgnoreCaseAndProducerProfile_User_IsActiveTrueOrderByStartedAtDesc(
      String status, String verificationStatus, Pageable pageable);
}
