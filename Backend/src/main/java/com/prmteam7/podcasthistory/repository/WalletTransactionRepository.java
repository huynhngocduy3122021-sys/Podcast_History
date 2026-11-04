package com.prmteam7.podcasthistory.repository;

import java.util.Optional;
import java.util.UUID;
import java.util.Collection;
import java.util.List;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.prmteam7.podcasthistory.model.WalletTransaction;

public interface WalletTransactionRepository
        extends JpaRepository<WalletTransaction, UUID>, JpaSpecificationExecutor<WalletTransaction> {

    @Query("""
            select transaction from WalletTransaction transaction
            where transaction.userWallet.user.userId = :userId
              and (:status is null or :status = '' or upper(transaction.status) = upper(:status))
            """)
    Page<WalletTransaction> findForUser(
            @Param("userId") UUID userId,
            @Param("status") String status,
            Pageable pageable);

    boolean existsByPayment_PaymentIdAndTransactionType(UUID paymentId, String transactionType);
    boolean existsByReferenceCode(String referenceCode);

    @Query("""
            select transaction.currency, coalesce(sum(transaction.amount), 0)
            from WalletTransaction transaction
            where upper(transaction.transactionType) = 'PLATFORM_FEE'
              and upper(transaction.direction) = 'CREDIT'
              and upper(transaction.status) = 'COMPLETED'
            group by transaction.currency
            """)
    List<Object[]> platformFeesByCurrency();

    @Query("""
            select transaction.payment.paymentId, coalesce(sum(transaction.amount), 0)
            from WalletTransaction transaction
            where transaction.payment.paymentId in :paymentIds
              and upper(transaction.transactionType) = 'PLATFORM_FEE'
              and upper(transaction.direction) = 'CREDIT'
              and upper(transaction.status) = 'COMPLETED'
            group by transaction.payment.paymentId
            """)
    List<Object[]> platformFeesByPaymentIds(@Param("paymentIds") Collection<UUID> paymentIds);

    boolean existsByPayment_PaymentIdAndStatus(UUID paymentId, String status);

    Optional<WalletTransaction> findByWithdrawalRequest_WithdrawalRequestIdAndStatus(
            UUID withdrawalRequestId, String status);

    Optional<WalletTransaction> findFirstByWithdrawalRequest_WithdrawalRequestIdAndTransactionType(
            UUID withdrawalRequestId, String transactionType);
}
