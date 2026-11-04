package com.prmteam7.podcasthistory.repository;

import java.util.List;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.prmteam7.podcasthistory.model.MilestoneDispute;

public interface MilestoneDisputeRepository extends JpaRepository<MilestoneDispute, UUID> {

    List<MilestoneDispute> findAllByStatusOrderByCreatedAtAsc(String status);
    List<MilestoneDispute> findAllByStatusAndCreatedAtBefore(String status, Instant deadline);

    Optional<MilestoneDispute> findFirstByContractStage_ContractStageIdAndStatus(
            UUID stageId, String status);

    Optional<MilestoneDispute> findFirstByContractStage_ContractStageIdAndDecisionOrderByResolvedAtDesc(
            UUID stageId, String decision);

    @Query("select dispute.contractStage.contract.contractId from MilestoneDispute dispute where dispute.milestoneDisputeId = :disputeId")
    Optional<UUID> findContractIdByDisputeId(@Param("disputeId") UUID disputeId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select dispute from MilestoneDispute dispute where dispute.milestoneDisputeId = :disputeId")
    Optional<MilestoneDispute> findByIdForUpdate(@Param("disputeId") UUID disputeId);
}
