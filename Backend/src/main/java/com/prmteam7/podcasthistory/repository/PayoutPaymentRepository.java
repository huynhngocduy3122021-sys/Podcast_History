package com.prmteam7.podcasthistory.repository;

import java.util.List;
import java.util.UUID;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.prmteam7.podcasthistory.model.Payment;

public interface PayoutPaymentRepository extends JpaRepository<Payment, UUID> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            select payment
            from Payment payment
            join fetch payment.contractStage stage
            join fetch stage.contract contract
            join fetch contract.producerProfile creator
            where creator.user.userId = :creatorUserId
              and payment.status = 'PAID'
              and stage.status = 'APPROVED'
            order by payment.paidAt asc, payment.paymentId asc
            """)
    List<Payment> findPaidApprovedMilestonesForRelease(@Param("creatorUserId") UUID creatorUserId);
}
