package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.Check;

@Entity
@Table(name = "\"Checkout_payment\"", indexes = {
    @Index(name = "uk_checkout_payment_code", columnList = "payment_code", unique = true),
    @Index(name = "uk_checkout_provider_transaction", columnList = "provider_transaction_id", unique = true)
})
@Check(constraints = "amount > 0 AND ((purpose = 'WALLET_TOPUP' AND creator_subscription_id IS NULL) OR (purpose = 'CREATOR_PLAN' AND creator_subscription_id IS NOT NULL))")
public class CheckoutPayment extends BaseEntity {
  @Id
  @Column(name = "checkout_id", nullable = false, updatable = false)
  private UUID checkoutId;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "user_id", nullable = false)
  private AppUser user;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "creator_subscription_id")
  private CreatorSystemSubscription creatorSubscription;

  @Column(name = "purpose", nullable = false, length = 30)
  private String purpose;

  @Column(name = "amount", nullable = false, precision = 12, scale = 2)
  private BigDecimal amount;

  @Column(name = "currency", nullable = false, length = 3)
  private String currency;

  @Column(name = "payment_code", nullable = false, length = 64, unique = true)
  private String paymentCode;

  @Column(name = "provider_transaction_id", unique = true, length = 180)
  private String providerTransactionId;

  @Column(name = "status", nullable = false, length = 30)
  private String status;

  @Column(name = "paid_at")
  private Instant paidAt;

  @PrePersist
  private void assignId() { if (checkoutId == null) checkoutId = UUID.randomUUID(); }

  public UUID getCheckoutId() { return checkoutId; }
  public void setCheckoutId(UUID value) { checkoutId = value; }
  public AppUser getUser() { return user; }
  public void setUser(AppUser value) { user = value; }
  public CreatorSystemSubscription getCreatorSubscription() { return creatorSubscription; }
  public void setCreatorSubscription(CreatorSystemSubscription value) { creatorSubscription = value; }
  public String getPurpose() { return purpose; }
  public void setPurpose(String value) { purpose = value; }
  public BigDecimal getAmount() { return amount; }
  public void setAmount(BigDecimal value) { amount = value; }
  public String getCurrency() { return currency; }
  public void setCurrency(String value) { currency = value; }
  public String getPaymentCode() { return paymentCode; }
  public void setPaymentCode(String value) { paymentCode = value; }
  public String getProviderTransactionId() { return providerTransactionId; }
  public void setProviderTransactionId(String value) { providerTransactionId = value; }
  public String getStatus() { return status; }
  public void setStatus(String value) { status = value; }
  public Instant getPaidAt() { return paidAt; }
  public void setPaidAt(Instant value) { paidAt = value; }
}
