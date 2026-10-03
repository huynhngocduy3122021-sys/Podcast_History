package com.prmteam7.podcasthistory.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.Check;

@Entity
@Table(name = "payment", uniqueConstraints = {
        @UniqueConstraint(name = "uk_payment_provider_transaction_id", columnNames = {"provider_transaction_id"})
    }, indexes = {
        @Index(name = "idx_payment_user_id", columnList = "user_id"),
        @Index(name = "idx_payment_subscription_id", columnList = "subscription_id"),
        @Index(name = "idx_payment_series_request_id", columnList = "series_request_id")
    })
@Check(constraints = "(subscription_id IS NOT NULL AND series_request_id IS NULL) OR (subscription_id IS NULL AND series_request_id IS NOT NULL)")
public class Payment extends BaseEntity {
    @Id
    @Column(name = "payment_id", nullable = false, updatable = false)
    private UUID paymentId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "subscription_id", nullable = true)
    private Subscription subscription;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "series_request_id", nullable = true)
    private SeriesRequest seriesRequest;

    @Column(name = "amount", nullable = false, precision = 12, scale = 2)
    private BigDecimal amount;

    @Column(name = "currency", nullable = false, length = 3, columnDefinition = "char(3)")
    private String currency;

    @Column(name = "payment_method", nullable = false, length = 40)
    private String paymentMethod;

    @Column(name = "provider", nullable = true, length = 60)
    private String provider;

    @Column(name = "provider_transaction_id", nullable = true, length = 180)
    private String providerTransactionId;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    @Column(name = "paid_at", nullable = true)
    private Instant paidAt;

    public Payment() {
    }

    @PrePersist
    private void assignId() {
        if (paymentId == null) {
            paymentId = UUID.randomUUID();
        }
    }

    public UUID getPaymentId() {
        return paymentId;
    }

    public void setPaymentId(UUID paymentId) {
        this.paymentId = paymentId;
    }

    public AppUser getUser() {
        return user;
    }

    public void setUser(AppUser user) {
        this.user = user;
    }

    public Subscription getSubscription() {
        return subscription;
    }

    public void setSubscription(Subscription subscription) {
        this.subscription = subscription;
    }

    public SeriesRequest getSeriesRequest() {
        return seriesRequest;
    }

    public void setSeriesRequest(SeriesRequest seriesRequest) {
        this.seriesRequest = seriesRequest;
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

    public String getPaymentMethod() {
        return paymentMethod;
    }

    public void setPaymentMethod(String paymentMethod) {
        this.paymentMethod = paymentMethod;
    }

    public String getProvider() {
        return provider;
    }

    public void setProvider(String provider) {
        this.provider = provider;
    }

    public String getProviderTransactionId() {
        return providerTransactionId;
    }

    public void setProviderTransactionId(String providerTransactionId) {
        this.providerTransactionId = providerTransactionId;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public Instant getPaidAt() {
        return paidAt;
    }

    public void setPaidAt(Instant paidAt) {
        this.paidAt = paidAt;
    }

}
