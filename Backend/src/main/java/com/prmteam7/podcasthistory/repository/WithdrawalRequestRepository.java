package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.WithdrawalRequest;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.*;

public interface WithdrawalRequestRepository
    extends JpaRepository<WithdrawalRequest, UUID>, JpaSpecificationExecutor<WithdrawalRequest> {
  long countByStatus(String status);

  boolean existsByPayoutReference(String reference);

  @Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
  @Query("select w from WithdrawalRequest w where w.withdrawalRequestId=:id")
  Optional<WithdrawalRequest> lockById(
      @org.springframework.data.repository.query.Param("id") UUID id);
}
