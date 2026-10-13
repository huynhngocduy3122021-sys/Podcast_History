package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.ContractStage;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ContractStageRepository extends JpaRepository<ContractStage, UUID> {
  List<ContractStage> findAllByContract_ContractIdOrderByStageOrderAsc(UUID id);
}
