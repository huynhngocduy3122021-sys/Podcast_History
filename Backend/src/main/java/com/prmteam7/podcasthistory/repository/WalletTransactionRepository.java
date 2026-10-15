package com.prmteam7.podcasthistory.repository;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.WalletTransaction;

public interface WalletTransactionRepository extends JpaRepository<WalletTransaction, UUID> {

    boolean existsByPayment_PaymentIdAndTransactionType(UUID paymentId, String transactionType);

    Optional<WalletTransaction> findFirstByWithdrawalRequest_WithdrawalRequestIdAndTransactionType(
            UUID withdrawalRequestId, String transactionType);
}
