package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.Check;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(
    name = "\"Withdrawal_request\"",
    indexes = {
      @Index(
          name = "idx_withdrawal_request_producer_profile_id",
          columnList = "producer_profile_id"),
      @Index(name = "idx_withdrawal_request_user_wallet_id", columnList = "user_wallet_id")
    })
@Check(constraints = "amount > 0")
public class WithdrawalRequest extends UpdatedEntity {
  @Column(name = "funds_reserved", nullable = false, columnDefinition = "boolean default false")
  private Boolean fundsReserved = false;

  @Column(name = "payout_reference", length = 180, unique = true)
  private String payoutReference;

  public boolean isFundsReserved() {
    return Boolean.TRUE.equals(fundsReserved);
  }

  public void setFundsReserved(boolean value) {
    fundsReserved = value;
  }

  public String getPayoutReference() {
    return payoutReference;
  }

  public void setPayoutReference(String value) {
    payoutReference = value;
  }

  @Id
  @Column(name = "withdrawal_request_id", nullable = false, updatable = false)
  private UUID withdrawalRequestId;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "producer_profile_id", nullable = false)
  private ProducerProfile producerProfile;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "user_wallet_id", nullable = false)
  private UserWallet userWallet;

  @Column(name = "amount", nullable = false, precision = 14, scale = 2)
  private BigDecimal amount;

  @JdbcTypeCode(SqlTypes.CHAR)
  @Column(name = "currency", nullable = false, length = 3, columnDefinition = "char(3)")
  private String currency;

  @Column(name = "payout_method", nullable = false, length = 40)
  private String payoutMethod;

  @Column(name = "payout_account_masked", nullable = false, length = 160)
  private String payoutAccountMasked;

  @Column(name = "status", nullable = false, length = 30)
  private String status;

  @Column(name = "requested_at", nullable = false)
  private Instant requestedAt;

  @Column(name = "processed_at", nullable = true)
  private Instant processedAt;

  @Column(name = "note", nullable = true, columnDefinition = "text")
  private String note;

  public WithdrawalRequest() {}

  @PrePersist
  private void assignId() {
    if (withdrawalRequestId == null) {
      withdrawalRequestId = UUID.randomUUID();
    }
  }

  public UUID getWithdrawalRequestId() {
    return withdrawalRequestId;
  }

  public void setWithdrawalRequestId(UUID withdrawalRequestId) {
    this.withdrawalRequestId = withdrawalRequestId;
  }

  public ProducerProfile getProducerProfile() {
    return producerProfile;
  }

  public void setProducerProfile(ProducerProfile producerProfile) {
    this.producerProfile = producerProfile;
  }

  public UserWallet getUserWallet() {
    return userWallet;
  }

  public void setUserWallet(UserWallet userWallet) {
    this.userWallet = userWallet;
  }

  public BigDecimal getAmount() {
    return amount;
  }

  public void setAmount(BigDecimal amount) {
    this.amount = amount;
  }

  public String getCurrency() {
    return currency;
  }

  public void setCurrency(String currency) {
    this.currency = currency;
  }

  public String getPayoutMethod() {
    return payoutMethod;
  }

  public void setPayoutMethod(String payoutMethod) {
    this.payoutMethod = payoutMethod;
  }

  public String getPayoutAccountMasked() {
    return payoutAccountMasked;
  }

  public void setPayoutAccountMasked(String payoutAccountMasked) {
    this.payoutAccountMasked = payoutAccountMasked;
  }

  public String getStatus() {
    return status;
  }

  public void setStatus(String status) {
    this.status = status;
  }

  public Instant getRequestedAt() {
    return requestedAt;
  }

  public void setRequestedAt(Instant requestedAt) {
    this.requestedAt = requestedAt;
  }

  public Instant getProcessedAt() {
    return processedAt;
  }

  public void setProcessedAt(Instant processedAt) {
    this.processedAt = processedAt;
  }

  public String getNote() {
    return note;
  }

  public void setNote(String note) {
    this.note = note;
  }
}
