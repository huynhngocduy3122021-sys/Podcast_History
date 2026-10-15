package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.WalletTransaction;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.*;

public interface WalletTransactionRepository
    extends JpaRepository<WalletTransaction, UUID>, JpaSpecificationExecutor<WalletTransaction> {
  boolean existsByPayment_PaymentIdAndStatus(UUID id, String status);

  Optional<WalletTransaction> findByWithdrawalRequest_WithdrawalRequestIdAndStatus(
      UUID id, String status);
}
