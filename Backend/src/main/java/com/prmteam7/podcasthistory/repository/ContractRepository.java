package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.Contract;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.*;

public interface ContractRepository
    extends JpaRepository<Contract, UUID>, JpaSpecificationExecutor<Contract> {
  @Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
  @Query("select c from Contract c where c.contractId=:id")
  Optional<Contract> lockById(@org.springframework.data.repository.query.Param("id") UUID id);
  Optional<Contract> findBySeriesResponse_SeriesRequest_SeriesRequestId(UUID requestId);
}
