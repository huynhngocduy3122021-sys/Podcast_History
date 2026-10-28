package com.prmteam7.podcasthistory.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "\"Contract_stage\"", uniqueConstraints = {
        @UniqueConstraint(name = "uk_contract_stage_order", columnNames = {"contract_id", "stage_order"})
    }, indexes = {
        @Index(name = "idx_contract_stage_contract_id", columnList = "contract_id")
    })
public class ContractStage extends UpdatedEntity {

    @jakarta.persistence.Id
    @Column(name = "contract_stage_id", nullable = false, updatable = false)
    private UUID contractStageId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "contract_id", nullable = false)
    private Contract contract;

    @Column(name = "stage_name", nullable = false, length = 150)
    private String stageName;

    @Column(name = "description", columnDefinition = "text")
    private String description;

    @Column(name = "stage_order", nullable = false)
    private Integer stageOrder;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    @Column(name = "amount", nullable = false, precision = 12, scale = 2,
            columnDefinition = "numeric(12,2) default 0.00")
    private BigDecimal amount;

    @Column(name = "due_at")
    private Instant dueAt;

    public ContractStage() {
    }

    @PrePersist
    private void assignId() {
        if (contractStageId == null) {
            contractStageId = UUID.randomUUID();
        }
    }

    public UUID getContractStageId() {
        return contractStageId;
    }

    public void setContractStageId(UUID contractStageId) {
        this.contractStageId = contractStageId;
    }

    public Contract getContract() {
        return contract;
    }

    public void setContract(Contract contract) {
        this.contract = contract;
    }

    public String getStageName() {
        return stageName;
    }

    public void setStageName(String stageName) {
        this.stageName = stageName;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public Integer getStageOrder() {
        return stageOrder;
    }

    public void setStageOrder(Integer stageOrder) {
        this.stageOrder = stageOrder;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public void setAmount(BigDecimal amount) {
        this.amount = amount;
    }

    public Instant getDueAt() { return dueAt; }
    public void setDueAt(Instant dueAt) { this.dueAt = dueAt; }
}
