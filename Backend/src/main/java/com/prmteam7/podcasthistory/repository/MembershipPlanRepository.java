package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.MembershipPlan;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MembershipPlanRepository
    extends JpaRepository<MembershipPlan, UUID>,
        org.springframework.data.jpa.repository.JpaSpecificationExecutor<MembershipPlan> {
  @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
  @org.springframework.data.jpa.repository.Query(
      "select p from MembershipPlan p where p.membershipPlanId=:id")
  Optional<MembershipPlan> lockById(@org.springframework.data.repository.query.Param("id") UUID id);

  List<MembershipPlan> findAllByProducerProfile_ProducerProfileIdAndStatusIgnoreCaseOrderByPriceAsc(
      UUID creatorId, String status);

  Optional<MembershipPlan>
      findByMembershipPlanIdAndProducerProfile_ProducerProfileIdAndStatusIgnoreCase(
          UUID planId, UUID creatorId, String status);
}
