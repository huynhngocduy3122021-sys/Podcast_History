package com.prmteam7.podcasthistory.repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.prmteam7.podcasthistory.model.Payment;

public interface PayoutPaymentRepository extends JpaRepository<Payment, UUID> {

    @Query("""
            select coalesce(sum(payment.amount), 0)
            from Payment payment
            join payment.contractStage stage
            join stage.contract contract
            join contract.producerProfile creator
            where creator.user.userId = :creatorUserId
              and upper(payment.status) in ('PAID', 'SUCCESS', 'COMPLETED')
              and upper(stage.status) = 'APPROVED'
              and upper(payment.currency) = upper(:currency)
              and exists (
                  select paymentMethod.paymentMethodId
                  from PaymentMethod paymentMethod
                  where paymentMethod.payment = payment
                    and paymentMethod.isActive = true
              )
              and not exists (
                  select transaction.walletTransactionId
                  from WalletTransaction transaction
                  where transaction.payment = payment
                    and transaction.transactionType = 'RELEASE_FUNDS'
              )
            """)
    BigDecimal sumPaidApprovedMilestonesPendingRelease(
            @Param("creatorUserId") UUID creatorUserId,
            @Param("currency") String currency);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            select payment
            from Payment payment
            join fetch payment.contractStage stage
            join fetch stage.contract contract
            join fetch contract.producerProfile creator
            where creator.user.userId = :creatorUserId
              and upper(payment.status) in ('PAID', 'SUCCESS', 'COMPLETED')
              and upper(stage.status) = 'APPROVED'
              and exists (
                  select paymentMethod.paymentMethodId
                  from PaymentMethod paymentMethod
                  where paymentMethod.payment = payment
                    and paymentMethod.isActive = true
              )
            order by payment.paidAt asc, payment.paymentId asc
            """)
    List<Payment> findPaidApprovedMilestonesForRelease(@Param("creatorUserId") UUID creatorUserId);
}
