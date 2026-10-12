package com.prmteam7.podcasthistory.repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.Subscription;

public interface SubscriptionRepository extends JpaRepository<Subscription, UUID> {

    List<Subscription> findAllByUser_UserIdOrderByCreatedAtDesc(UUID userId);

    boolean existsByUser_UserIdAndMembershipPlan_ProducerProfile_ProducerProfileIdAndStatusIgnoreCaseAndEndAtAfter(
            UUID userId, UUID creatorId, String status, Instant now);

    Optional<Subscription> findTopByUser_UserIdAndMembershipPlan_ProducerProfile_ProducerProfileIdAndStatusIgnoreCaseAndEndAtAfterOrderByEndAtDesc(
            UUID userId, UUID creatorId, String status, Instant now);

    boolean existsByUser_UserIdAndMembershipPlan_ProducerProfile_ProducerProfileIdAndStatusIgnoreCaseAndStartAtBeforeAndEndAtAfter(
            UUID userId, UUID creatorId, String status, Instant now, Instant nowForEnd);

    boolean existsByUser_UserIdAndMembershipPlan_ProducerProfile_ProducerProfileIdAndStatusIgnoreCaseAndEndAtAfterAndMembershipPlan_MembershipPlanId(
            UUID userId, UUID creatorId, String status, Instant now, UUID planId);

    boolean existsByUser_UserIdAndMembershipPlan_MembershipPlanIdAndStatusIgnoreCase(
            UUID userId, UUID planId, String status);
}
