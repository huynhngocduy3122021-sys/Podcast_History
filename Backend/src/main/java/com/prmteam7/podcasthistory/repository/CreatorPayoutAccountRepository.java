package com.prmteam7.podcasthistory.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.EntityGraph;

import com.prmteam7.podcasthistory.model.CreatorPayoutAccount;

public interface CreatorPayoutAccountRepository extends JpaRepository<CreatorPayoutAccount, UUID> {

    Optional<CreatorPayoutAccount> findByCreatorPayoutAccountIdAndProducerProfile_ProducerProfileId(
            UUID accountId, UUID producerProfileId);

    List<CreatorPayoutAccount> findAllByProducerProfile_ProducerProfileIdAndActiveTrueOrderByCreatedAtDesc(
            UUID producerProfileId);

    List<CreatorPayoutAccount> findAllByProducerProfile_ProducerProfileIdOrderByCreatedAtDesc(
            UUID producerProfileId);

    @EntityGraph(attributePaths = {"producerProfile", "producerProfile.user"})
    List<CreatorPayoutAccount> findAllByActiveTrueOrderByVerifiedAscCreatedAtDesc();

    boolean existsByAccountReference(String accountReference);
}
