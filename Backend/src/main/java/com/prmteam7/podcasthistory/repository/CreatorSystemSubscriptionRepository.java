package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.CreatorSystemSubscription;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CreatorSystemSubscriptionRepository extends JpaRepository<CreatorSystemSubscription, UUID> {
  Optional<CreatorSystemSubscription>
      findTopByProducerProfile_ProducerProfileIdAndPaymentStatusAndStartAtLessThanEqualAndEndAtAfterOrderByEndAtDesc(
          UUID creatorId, String paymentStatus, Instant now, Instant endNow);
}
