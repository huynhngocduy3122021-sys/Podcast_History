package com.prmteam7.podcasthistory.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.MilestoneRevision;

public interface MilestoneRevisionRepository extends JpaRepository<MilestoneRevision, UUID> {

    long countByContractStage_ContractStageId(UUID stageId);

    long countByContractStage_ContractStageIdAndRequestedBy_UserId(UUID stageId, UUID userId);
}
