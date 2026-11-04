package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.Subscription;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SubscriptionRepository extends JpaRepository<Subscription, UUID> {
  @Query(value = """
      select s from Subscription s
      join fetch s.user member
      join fetch s.membershipPlan plan
      where plan.producerProfile.producerProfileId = :creatorId
        and (:status is null or upper(s.status) = :status)
        and (:status <> 'ACTIVE' or (s.startAt <= :now and s.endAt > :now))
      """, countQuery = """
      select count(s) from Subscription s
      where s.membershipPlan.producerProfile.producerProfileId = :creatorId
        and (:status is null or upper(s.status) = :status)
        and (:status <> 'ACTIVE' or (s.startAt <= :now and s.endAt > :now))
      """)
  Page<Subscription> findChannelMembers(@Param("creatorId") UUID creatorId,
      @Param("status") String status, @Param("now") Instant now, Pageable pageable);
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
  Optional<Subscription> findFirstByUser_UserIdAndMembershipPlan_MembershipPlanIdAndStatusIgnoreCaseOrderByCreatedAtDesc(
      UUID userId, UUID planId, String status);
  Optional<Subscription> findFirstByUser_UserIdAndMembershipPlan_ProducerProfile_ProducerProfileIdAndStatusIgnoreCaseOrderByCreatedAtDesc(
      UUID userId, UUID creatorId, String status);
}
