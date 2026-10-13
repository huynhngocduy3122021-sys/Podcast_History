package com.prmteam7.podcasthistory.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.Contract;

public interface ContractRepository extends JpaRepository<Contract, UUID> {

    Optional<Contract> findBySeriesResponse_SeriesRequest_SeriesRequestId(UUID requestId);
}
