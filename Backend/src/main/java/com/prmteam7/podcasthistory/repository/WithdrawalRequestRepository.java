package com.prmteam7.podcasthistory.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.prmteam7.podcasthistory.model.WithdrawalRequest;

public interface WithdrawalRequestRepository extends JpaRepository<WithdrawalRequest, UUID> {

    List<WithdrawalRequest> findAllByProducerProfile_ProducerProfileIdOrderByRequestedAtDesc(UUID producerProfileId);

    List<WithdrawalRequest> findAllByStatusOrderByRequestedAtAsc(String status);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select withdrawal from WithdrawalRequest withdrawal where withdrawal.withdrawalRequestId = :id")
    Optional<WithdrawalRequest> findByIdForUpdate(@Param("id") UUID id);
}
