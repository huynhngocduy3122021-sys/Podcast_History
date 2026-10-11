package com.prmteam7.podcasthistory.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import jakarta.persistence.Id;
import java.util.UUID;

@Entity
@Table(name = "\"Payment_method\"", indexes = {
        @Index(name = "idx_payment_method_payment_id", columnList = "payment_id"),
        @Index(name = "idx_payment_method_code", columnList = "method_code")
    })
public class PaymentMethod extends BaseEntity {

    @Id
    @Column(name = "payment_method_id", nullable = false, updatable = false)
    private UUID paymentMethodId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "payment_id", nullable = false)
    private Payment payment;

    @Column(name = "method_code", nullable = false, length = 40)
    private String methodCode;

    @Column(name = "display_name", nullable = false, length = 100)
    private String displayName;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive;

    public PaymentMethod() {
    }

    @PrePersist
    private void assignId() {
        if (paymentMethodId == null) {
            paymentMethodId = UUID.randomUUID();
        }
        if (isActive == null) {
            isActive = true;
        }
    }

    public UUID getPaymentMethodId() {
        return paymentMethodId;
    }

    public void setPaymentMethodId(UUID paymentMethodId) {
        this.paymentMethodId = paymentMethodId;
    }

    public Payment getPayment() {
        return payment;
    }

    public void setPayment(Payment payment) {
        this.payment = payment;
    }

    public String getMethodCode() {
        return methodCode;
    }

    public void setMethodCode(String methodCode) {
        this.methodCode = methodCode;
    }

    public String getDisplayName() {
        return displayName;
    }

    public void setDisplayName(String displayName) {
        this.displayName = displayName;
    }

    public Boolean getIsActive() {
        return isActive;
    }

    public void setIsActive(Boolean active) {
        isActive = active;
    }
}
