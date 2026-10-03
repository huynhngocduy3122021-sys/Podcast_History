package com.prmteam7.podcasthistory.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "user_wallet", indexes = {
        @Index(name = "idx_user_wallet_user_id", columnList = "user_id")
    })
public class UserWallet extends UpdatedEntity {
    @Id
    @Column(name = "user_wallet_id", nullable = false, updatable = false)
    private UUID userWalletId;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @Column(name = "balance", nullable = false, precision = 14, scale = 2)
    private BigDecimal balance;

    @Column(name = "currency", nullable = false, length = 3, columnDefinition = "char(3)")
    private String currency;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    public UserWallet() {
    }

    @PrePersist
    private void assignId() {
        if (userWalletId == null) {
            userWalletId = UUID.randomUUID();
        }
    }

    public UUID getUserWalletId() {
        return userWalletId;
    }

    public void setUserWalletId(UUID userWalletId) {
        this.userWalletId = userWalletId;
    }

    public AppUser getUser() {
        return user;
    }

    public void setUser(AppUser user) {
        this.user = user;
    }

    public BigDecimal getBalance() {
        return balance;
    }

    public void setBalance(BigDecimal balance) {
        this.balance = balance;
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

}
