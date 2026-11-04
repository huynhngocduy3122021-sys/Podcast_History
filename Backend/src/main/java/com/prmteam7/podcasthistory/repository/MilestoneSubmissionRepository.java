package com.prmteam7.podcasthistory.repository;

import java.util.List;
import java.util.UUID;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.MilestoneSubmission;

public interface MilestoneSubmissionRepository extends JpaRepository<MilestoneSubmission, UUID> {

    List<MilestoneSubmission> findAllByContractStage_ContractStageIdOrderByRevisionNumberAsc(UUID stageId);

    long countByContractStage_ContractStageId(UUID stageId);
    Optional<MilestoneSubmission> findFirstByContractStage_ContractStageIdOrderBySubmittedAtDesc(UUID stageId);
}
