package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.Subscription;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SubscriptionRepository extends JpaRepository<Subscription, UUID> {
  boolean existsByMembershipPlan_MembershipPlanId(UUID planId);

  @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
  @org.springframework.data.jpa.repository.Query(
      "select s from Subscription s where s.subscriptionId=:id")
  Optional<Subscription> lockById(@org.springframework.data.repository.query.Param("id") UUID id);

  @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"membershipPlan", "membershipPlan.producerProfile"})
  List<Subscription> findAllByUser_UserIdOrderByCreatedAtDesc(UUID userId);

  boolean
      existsByUser_UserIdAndMembershipPlan_ProducerProfile_ProducerProfileIdAndStatusIgnoreCaseAndEndAtAfter(
          UUID userId, UUID creatorId, String status, Instant now);

  Optional<Subscription>
      findTopByUser_UserIdAndMembershipPlan_ProducerProfile_ProducerProfileIdAndStatusIgnoreCaseAndEndAtAfterOrderByEndAtDesc(
          UUID userId, UUID creatorId, String status, Instant now);

  boolean
      existsByUser_UserIdAndMembershipPlan_ProducerProfile_ProducerProfileIdAndStatusIgnoreCaseAndStartAtBeforeAndEndAtAfter(
          UUID userId, UUID creatorId, String status, Instant now, Instant nowForEnd);

  boolean
      existsByUser_UserIdAndMembershipPlan_ProducerProfile_ProducerProfileIdAndStatusIgnoreCaseAndEndAtAfterAndMembershipPlan_MembershipPlanId(
          UUID userId, UUID creatorId, String status, Instant now, UUID planId);

  boolean existsByUser_UserIdAndMembershipPlan_MembershipPlanIdAndStatusIgnoreCase(
      UUID userId, UUID planId, String status);
}
