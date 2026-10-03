package com.prmteam7.podcasthistory.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "producer_earning", indexes = {
        @Index(name = "idx_producer_earning_producer_profile_id", columnList = "producer_profile_id"),
        @Index(name = "idx_producer_earning_payment_id", columnList = "payment_id")
    })
public class ProducerEarning extends BaseEntity {
    @Id
    @Column(name = "producer_earning_id", nullable = false, updatable = false)
    private UUID producerEarningId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "producer_profile_id", nullable = false)
    private ProducerProfile producerProfile;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "payment_id", nullable = false)
    private Payment payment;

    @Column(name = "gross_amount", nullable = false, precision = 14, scale = 2)
    private BigDecimal grossAmount;

    @Column(name = "platform_fee", nullable = false, precision = 14, scale = 2)
    private BigDecimal platformFee;

    @Column(name = "net_amount", nullable = false, precision = 14, scale = 2)
    private BigDecimal netAmount;

    @Column(name = "currency", nullable = false, length = 3, columnDefinition = "char(3)")
    private String currency;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    @Column(name = "earned_at", nullable = false)
    private Instant earnedAt;

    @Column(name = "available_at", nullable = true)
    private Instant availableAt;

    public ProducerEarning() {
    }

    @PrePersist
    private void assignId() {
        if (producerEarningId == null) {
            producerEarningId = UUID.randomUUID();
        }
    }

    public UUID getProducerEarningId() {
        return producerEarningId;
    }

    public void setProducerEarningId(UUID producerEarningId) {
        this.producerEarningId = producerEarningId;
    }

    public ProducerProfile getProducerProfile() {
        return producerProfile;
    }

    public void setProducerProfile(ProducerProfile producerProfile) {
        this.producerProfile = producerProfile;
    }

    public Payment getPayment() {
        return payment;
    }

    public void setPayment(Payment payment) {
        this.payment = payment;
    }

    public BigDecimal getGrossAmount() {
        return grossAmount;
    }

    public void setGrossAmount(BigDecimal grossAmount) {
        this.grossAmount = grossAmount;
    }

    public BigDecimal getPlatformFee() {
        return platformFee;
    }

    public void setPlatformFee(BigDecimal platformFee) {
        this.platformFee = platformFee;
    }

    public BigDecimal getNetAmount() {
        return netAmount;
    }

    public void setNetAmount(BigDecimal netAmount) {
        this.netAmount = netAmount;
    }

    public String getCurrency() {
        return currency;
    }

    public void setCurrency(String currency) {
        this.currency = currency;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public Instant getEarnedAt() {
        return earnedAt;
    }

    public void setEarnedAt(Instant earnedAt) {
        this.earnedAt = earnedAt;
    }

    public Instant getAvailableAt() {
        return availableAt;
    }

    public void setAvailableAt(Instant availableAt) {
        this.availableAt = availableAt;
    }

}
