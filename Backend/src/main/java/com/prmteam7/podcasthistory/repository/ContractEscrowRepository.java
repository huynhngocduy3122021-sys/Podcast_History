package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.ContractEscrow;
import jakarta.persistence.LockModeType;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ContractEscrowRepository extends JpaRepository<ContractEscrow, UUID> {
    Optional<ContractEscrow> findByRequest_SeriesRequestId(UUID requestId);
    Optional<ContractEscrow> findByIdempotencyKey(UUID idempotencyKey);
    Optional<ContractEscrow> findByContract_ContractId(UUID contractId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select e from ContractEscrow e where e.request.seriesRequestId = :requestId")
    Optional<ContractEscrow> lockByRequestId(@Param("requestId") UUID requestId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select e from ContractEscrow e where e.contract.contractId = :contractId")
    Optional<ContractEscrow> lockByContractId(@Param("contractId") UUID contractId);
}
