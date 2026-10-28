package com.prmteam7.podcasthistory.repository;

import java.util.Optional;
import java.util.UUID;

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

    boolean existsByPayment_PaymentIdAndStatus(UUID paymentId, String status);

    Optional<WalletTransaction> findByWithdrawalRequest_WithdrawalRequestIdAndStatus(
            UUID withdrawalRequestId, String status);

    Optional<WalletTransaction> findFirstByWithdrawalRequest_WithdrawalRequestIdAndTransactionType(
            UUID withdrawalRequestId, String transactionType);
}
