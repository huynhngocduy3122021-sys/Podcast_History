package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import java.math.BigDecimal;
import java.util.UUID;
import org.hibernate.annotations.Check;

@Entity
@Table(name = "\"Wallet_Transaction\"", indexes = {
        @Index(name = "idx_wallet_transaction_user_wallet_id", columnList = "user_wallet_id"),
        @Index(name = "idx_wallet_transaction_system_wallet_id", columnList = "system_wallet_id"),
        @Index(name = "idx_wallet_transaction_producer_earning_id", columnList = "producer_earning_id"),
        @Index(name = "idx_wallet_transaction_withdrawal_request_id", columnList = "withdrawal_request_id"),
        @Index(name = "idx_wallet_transaction_contract_id", columnList = "contract_id")
    })
@Check(constraints = "amount > 0 AND (user_wallet_id IS NOT NULL OR system_wallet_id IS NOT NULL OR contract_id IS NOT NULL)")
public class WalletTransaction extends BaseEntity {
    @Id
    @Column(name = "wallet_transaction_id", nullable = false, updatable = false)
    private UUID walletTransactionId;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "user_wallet_id", nullable = true)
    private UserWallet userWallet;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "system_wallet_id", nullable = true)
    private SystemWallet systemWallet;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "producer_earning_id", nullable = true)
    private ProducerEarning producerEarning;

    @ManyToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "withdrawal_request_id", nullable = true)
    private WithdrawalRequest withdrawalRequest;

    @OneToOne(fetch = FetchType.LAZY, optional = true)
    @JoinColumn(name = "contract_id", nullable = true, unique = true)
    private Contract contract;

    @Column(name = "transaction_type", nullable = false, length = 30)
    private String transactionType;

    @Column(name = "direction", nullable = false, length = 10)
    private String direction;

    @Column(name = "amount", nullable = false, precision = 14, scale = 2)
    private BigDecimal amount;

    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(name = "currency", nullable = false, length = 3, columnDefinition = "char(3)")
    private String currency;

    @Column(name = "reference_code", nullable = true, length = 180)
    private String referenceCode;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    @Column(name = "balance_after", nullable = true, precision = 14, scale = 2)
    private BigDecimal balanceAfter;

    public WalletTransaction() {
    }

    @PrePersist
    private void assignId() {
        if (walletTransactionId == null) {
            walletTransactionId = UUID.randomUUID();
        }
    }

    public UUID getWalletTransactionId() {
        return walletTransactionId;
    }

    public void setWalletTransactionId(UUID walletTransactionId) {
        this.walletTransactionId = walletTransactionId;
    }

    public UserWallet getUserWallet() {
        return userWallet;
    }

    public void setUserWallet(UserWallet userWallet) {
        this.userWallet = userWallet;
    }

    public SystemWallet getSystemWallet() {
        return systemWallet;
    }

    public void setSystemWallet(SystemWallet systemWallet) {
        this.systemWallet = systemWallet;
    }

    public ProducerEarning getProducerEarning() {
        return producerEarning;
    }

    public void setProducerEarning(ProducerEarning producerEarning) {
        this.producerEarning = producerEarning;
    }

    public WithdrawalRequest getWithdrawalRequest() {
        return withdrawalRequest;
    }

    public void setWithdrawalRequest(WithdrawalRequest withdrawalRequest) {
        this.withdrawalRequest = withdrawalRequest;
    }

    public Contract getContract() {
        return contract;
    }

    public void setContract(Contract contract) {
        this.contract = contract;
    }

    public String getTransactionType() {
        return transactionType;
    }

    public void setTransactionType(String transactionType) {
        this.transactionType = transactionType;
    }

    public String getDirection() {
        return direction;
    }

    public void setDirection(String direction) {
        this.direction = direction;
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

    public String getReferenceCode() {
        return referenceCode;
    }

    public void setReferenceCode(String referenceCode) {
        this.referenceCode = referenceCode;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public BigDecimal getBalanceAfter() {
        return balanceAfter;
    }

    public void setBalanceAfter(BigDecimal balanceAfter) {
        this.balanceAfter = balanceAfter;
    }

}
