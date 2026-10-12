package com.prmteam7.podcasthistory.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.MembershipPlan;

public interface MembershipPlanRepository extends JpaRepository<MembershipPlan, UUID> {

    List<MembershipPlan> findAllByProducerProfile_ProducerProfileIdAndStatusIgnoreCaseOrderByPriceAsc(
            UUID creatorId, String status);

    Optional<MembershipPlan> findByMembershipPlanIdAndProducerProfile_ProducerProfileIdAndStatusIgnoreCase(
            UUID planId, UUID creatorId, String status);
}
