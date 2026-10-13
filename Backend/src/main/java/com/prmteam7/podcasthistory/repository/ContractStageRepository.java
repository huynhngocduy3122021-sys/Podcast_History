package com.prmteam7.podcasthistory.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.prmteam7.podcasthistory.model.ContractStage;

public interface ContractStageRepository extends JpaRepository<ContractStage, UUID> {

    List<ContractStage> findAllByContract_ContractIdOrderByStageOrder(UUID contractId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select stage from ContractStage stage where stage.contractStageId = :stageId")
    Optional<ContractStage> findByIdForUpdate(@Param("stageId") UUID stageId);
}
