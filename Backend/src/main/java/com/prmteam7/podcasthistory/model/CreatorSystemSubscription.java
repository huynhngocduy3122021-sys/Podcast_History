package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "\"Creator_system_subscription\"", indexes =
    @Index(name = "idx_creator_system_subscription_profile", columnList = "producer_profile_id"))
public class CreatorSystemSubscription extends BaseEntity {
  @Id
  @Column(name = "subscription_id", nullable = false, updatable = false)
  private UUID subscriptionId;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "producer_profile_id", nullable = false)
  private ProducerProfile producerProfile;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "plan_id", nullable = false)
  private CreatorSystemPlan plan;

  @Column(name = "start_at", nullable = false)
  private Instant startAt;

  @Column(name = "end_at", nullable = false)
  private Instant endAt;

  @Column(name = "amount", nullable = false, precision = 12, scale = 2)
  private BigDecimal amount;

  @Column(name = "currency", nullable = false, length = 3)
  private String currency;

  @Column(name = "payment_status", nullable = false, length = 30)
  private String paymentStatus;

  @Column(name = "payment_reference", nullable = false, unique = true, length = 100)
  private String paymentReference;

  @ElementCollection(fetch = FetchType.EAGER)
  @CollectionTable(name = "\"Creator_system_subscription_benefit\"",
      joinColumns = @JoinColumn(name = "subscription_id"))
  @OrderColumn(name = "sort_order")
  private List<CreatorSystemBenefit> benefits = new ArrayList<>();

  @PrePersist
  private void assignId() { if (subscriptionId == null) subscriptionId = UUID.randomUUID(); }

  public UUID getSubscriptionId() { return subscriptionId; }
  public ProducerProfile getProducerProfile() { return producerProfile; }
  public void setProducerProfile(ProducerProfile producerProfile) { this.producerProfile = producerProfile; }
  public CreatorSystemPlan getPlan() { return plan; }
  public void setPlan(CreatorSystemPlan plan) { this.plan = plan; }
  public Instant getStartAt() { return startAt; }
  public void setStartAt(Instant startAt) { this.startAt = startAt; }
  public Instant getEndAt() { return endAt; }
  public void setEndAt(Instant endAt) { this.endAt = endAt; }
  public BigDecimal getAmount() { return amount; }
  public void setAmount(BigDecimal amount) { this.amount = amount; }
  public String getCurrency() { return currency; }
  public void setCurrency(String currency) { this.currency = currency; }
  public String getPaymentStatus() { return paymentStatus; }
  public void setPaymentStatus(String paymentStatus) { this.paymentStatus = paymentStatus; }
  public String getPaymentReference() { return paymentReference; }
  public void setPaymentReference(String paymentReference) { this.paymentReference = paymentReference; }
  public List<CreatorSystemBenefit> getBenefits() { return benefits; }
  public void setBenefits(List<CreatorSystemBenefit> benefits) { this.benefits = benefits; }
}
