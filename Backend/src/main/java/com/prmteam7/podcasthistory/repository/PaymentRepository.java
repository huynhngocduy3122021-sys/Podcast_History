package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.Payment;
import java.util.Optional;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentRepository
    extends JpaRepository<Payment, UUID>,
        org.springframework.data.jpa.repository.JpaSpecificationExecutor<Payment> {

  @org.springframework.data.jpa.repository.Query("""
      select coalesce(sum(payment.amount), 0)
      from Payment payment
      where payment.contractStage.contract.producerProfile.producerProfileId = :creatorId
        and upper(payment.status) in ('PAID', 'SUCCESS', 'COMPLETED')
        and upper(payment.currency) = upper(:currency)
        and exists (
            select paymentMethod.paymentMethodId
            from PaymentMethod paymentMethod
            where paymentMethod.payment = payment
              and paymentMethod.isActive = true
        )
        and payment.paidAt >= :from
        and payment.paidAt < :to
      """)
  BigDecimal sumCreatorContractRevenue(
      @org.springframework.data.repository.query.Param("creatorId") UUID creatorId,
      @org.springframework.data.repository.query.Param("currency") String currency,
      @org.springframework.data.repository.query.Param("from") Instant from,
      @org.springframework.data.repository.query.Param("to") Instant to);

  @org.springframework.data.jpa.repository.Query("""
      select coalesce(sum(payment.amount), 0)
      from Payment payment
      where payment.subscription.membershipPlan.producerProfile.producerProfileId = :creatorId
        and upper(payment.status) in ('PAID', 'SUCCESS', 'COMPLETED')
        and upper(payment.currency) = upper(:currency)
        and exists (
            select paymentMethod.paymentMethodId
            from PaymentMethod paymentMethod
            where paymentMethod.payment = payment
              and paymentMethod.isActive = true
        )
        and payment.paidAt >= :from
        and payment.paidAt < :to
      """)
  BigDecimal sumCreatorMembershipRevenue(
      @org.springframework.data.repository.query.Param("creatorId") UUID creatorId,
      @org.springframework.data.repository.query.Param("currency") String currency,
      @org.springframework.data.repository.query.Param("from") Instant from,
      @org.springframework.data.repository.query.Param("to") Instant to);
  @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
  @org.springframework.data.jpa.repository.Query("select p from Payment p where p.paymentId=:id")
  Optional<Payment> lockById(@org.springframework.data.repository.query.Param("id") UUID id);

  boolean existsByProviderTransactionId(String reference);

  Optional<Payment> findByProviderTransactionId(String providerTransactionId);

  boolean existsByRefundReference(String reference);

  @org.springframework.data.jpa.repository.Query(
      "select count(p) from Payment p where p.contractStage.contract.contractId=:id and"
          + " upper(p.status) in ('PAID','SUCCESS','COMPLETED')")
  long countUnrefundedContractPayments(
      @org.springframework.data.repository.query.Param("id") UUID id);

  @org.springframework.data.jpa.repository.Query(
      "select p.currency, sum(p.amount) from Payment p where upper(p.status) in"
          + " ('PAID','SUCCESS','COMPLETED') group by p.currency")
  java.util.List<Object[]> collectedByCurrency();

  Optional<Payment> findFirstBySubscription_SubscriptionIdOrderByCreatedAtDesc(UUID subscriptionId);

  @org.springframework.data.jpa.repository.Query("select p from Payment p where p.subscription.subscriptionId in :ids and not exists (select newer.paymentId from Payment newer where newer.subscription = p.subscription and (newer.createdAt > p.createdAt or (newer.createdAt = p.createdAt and newer.paymentId > p.paymentId)))")
  java.util.List<Payment> findLatestBySubscriptions(@org.springframework.data.repository.query.Param("ids") java.util.Collection<UUID> ids);
  Optional<Payment> findFirstByContractStage_ContractStageId(UUID stageId);
}
