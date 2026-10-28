package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.CheckoutPayment;
import jakarta.persistence.LockModeType;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CheckoutPaymentRepository extends JpaRepository<CheckoutPayment, UUID> {
  @Modifying
  @Query("update CheckoutPayment c set c.status = 'FAILED' where c.purpose = 'WALLET_TOPUP' and c.status = 'PENDING' and c.createdAt < :cutoff")
  int failExpiredWalletTopUps(@Param("cutoff") java.time.Instant cutoff);
  @Query("""
      select checkout from CheckoutPayment checkout
      where checkout.user.userId = :userId
        and (:status is null or :status = '' or upper(checkout.status) = upper(:status))
      """)
  Page<CheckoutPayment> findForUser(
      @Param("userId") UUID userId,
      @Param("status") String status,
      Pageable pageable);

  boolean existsByPaymentCode(String code);
  boolean existsByProviderTransactionId(String transactionId);
  boolean existsByCreatorSubscription_SubscriptionIdAndStatus(UUID subscriptionId, String status);
  Optional<CheckoutPayment> findFirstByCreatorSubscription_ProducerProfile_ProducerProfileIdAndStatusOrderByCreatedAtDesc(
      UUID creatorId, String status);
  Optional<CheckoutPayment> findByCheckoutIdAndUser_UserId(UUID checkoutId, UUID userId);

  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select c from CheckoutPayment c where c.paymentCode=:code")
  Optional<CheckoutPayment> lockByPaymentCode(@Param("code") String code);

  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select c from CheckoutPayment c where c.checkoutId=:id")
  Optional<CheckoutPayment> lockById(@Param("id") UUID id);
}
