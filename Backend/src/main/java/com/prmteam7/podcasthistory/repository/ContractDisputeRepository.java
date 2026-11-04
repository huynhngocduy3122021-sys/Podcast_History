package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.ContractDispute;
import java.util.Optional;
import java.util.List;
import java.time.Instant;
import java.util.UUID;
import org.springframework.data.jpa.repository.*;

public interface ContractDisputeRepository
    extends JpaRepository<ContractDispute, UUID>, JpaSpecificationExecutor<ContractDispute> {
  long countByStatus(String status);

  boolean existsByContract_ContractIdAndStatus(UUID id, String status);
  Optional<ContractDispute> findFirstByContract_ContractIdAndStatus(UUID id, String status);
  Optional<ContractDispute> findFirstByContract_ContractIdOrderByCreatedAtDesc(UUID id);
  List<ContractDispute> findAllByStatusAndCreatedAtBefore(String status, Instant deadline);

  @Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
  @Query("select d from ContractDispute d where d.disputeId=:id")
  Optional<ContractDispute> lockById(
      @org.springframework.data.repository.query.Param("id") UUID id);
}
