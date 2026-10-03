package com.prmteam7.podcasthistory.entity;

import jakarta.persistence.*;
import com.prmteam7.podcasthistory.entity.BaseEntity;
import com.prmteam7.podcasthistory.entity.UpdatedEntity;
import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "system_wallet", uniqueConstraints = {
        @UniqueConstraint(name = "uk_system_wallet_wallet_code", columnNames = {"wallet_code"})
    })
public class SystemWallet extends UpdatedEntity {
    @Id
    @Column(name = "system_wallet_id", nullable = false, updatable = false)
    private UUID systemWalletId;

    @Column(name = "wallet_code", nullable = false, length = 50)
    private String walletCode;

    @Column(name = "name", nullable = false, length = 120)
    private String name;

    @Column(name = "balance", nullable = false, precision = 14, scale = 2)
    private BigDecimal balance;

    @Column(name = "currency", nullable = false, length = 3, columnDefinition = "char(3)")
    private String currency;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    public SystemWallet() {
    }

    @PrePersist
    private void assignId() {
        if (systemWalletId == null) {
            systemWalletId = UUID.randomUUID();
        }
    }

    public UUID getSystemWalletId() {
        return systemWalletId;
    }

    public void setSystemWalletId(UUID systemWalletId) {
        this.systemWalletId = systemWalletId;
    }

    public String getWalletCode() {
        return walletCode;
    }

    public void setWalletCode(String walletCode) {
        this.walletCode = walletCode;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
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
