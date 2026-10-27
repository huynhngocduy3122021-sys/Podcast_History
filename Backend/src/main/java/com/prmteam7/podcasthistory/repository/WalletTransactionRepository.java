package com.prmteam7.podcasthistory.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

import com.prmteam7.podcasthistory.model.WalletTransaction;

public interface WalletTransactionRepository
        extends JpaRepository<WalletTransaction, UUID>, JpaSpecificationExecutor<WalletTransaction> {

    boolean existsByPayment_PaymentIdAndTransactionType(UUID paymentId, String transactionType);
    boolean existsByReferenceCode(String referenceCode);

    boolean existsByPayment_PaymentIdAndStatus(UUID paymentId, String status);

    Optional<WalletTransaction> findByWithdrawalRequest_WithdrawalRequestIdAndStatus(
            UUID withdrawalRequestId, String status);

    Optional<WalletTransaction> findFirstByWithdrawalRequest_WithdrawalRequestIdAndTransactionType(
            UUID withdrawalRequestId, String transactionType);
}
