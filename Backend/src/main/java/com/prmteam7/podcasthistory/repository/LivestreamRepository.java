package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.Livestream;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

public interface LivestreamRepository extends JpaRepository<Livestream, UUID> {
  boolean existsByProducerProfile_ProducerProfileIdAndStatusIgnoreCase(UUID creatorId, String status);

  @EntityGraph(attributePaths = {"producerProfile"})
  List<Livestream> findAllByProducerProfile_ProducerProfileIdOrderByCreatedAtDesc(UUID creatorId);

  @EntityGraph(attributePaths = {"producerProfile"})
  Page<Livestream> findAllByStatusIgnoreCaseAndProducerProfile_VerificationStatusIgnoreCaseAndProducerProfile_User_IsActiveTrueOrderByStartedAtDesc(
      String status, String verificationStatus, Pageable pageable);
}
