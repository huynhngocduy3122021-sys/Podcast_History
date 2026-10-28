package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "contract_escrow", uniqueConstraints = {
        @UniqueConstraint(name = "uk_contract_escrow_request", columnNames = "series_request_id"),
        @UniqueConstraint(name = "uk_contract_escrow_contract", columnNames = "contract_id"),
        @UniqueConstraint(name = "uk_contract_escrow_idempotency", columnNames = "idempotency_key")
})
public class ContractEscrow extends BaseEntity {
    @Id
    @Column(name = "contract_escrow_id", nullable = false, updatable = false)
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "series_request_id", nullable = false)
    private SeriesRequest request;

    @Column(name = "idempotency_key", nullable = false, updatable = false)
    private UUID idempotencyKey;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "contract_id")
    private Contract contract;

    @Column(name = "budget", nullable = false, precision = 12, scale = 2)
    private BigDecimal budget;

    @Column(name = "remaining", nullable = false, precision = 12, scale = 2)
    private BigDecimal remaining;

    @Column(name = "product_type", nullable = false, length = 8)
    private String productType;

    @Column(name = "file_format", nullable = false, length = 60)
    private String fileFormat;

    @Column(name = "duration_description", nullable = false, length = 120)
    private String durationDescription;

    @Column(name = "acceptance_criteria", nullable = false, columnDefinition = "text")
    private String acceptanceCriteria;

    @Column(name = "auto_accept_enabled", nullable = false)
    private boolean autoAcceptEnabled;

    @Column(name = "contract_version")
    private Integer contractVersion;

    @Column(name = "content_hash", length = 64)
    private String contentHash;

    @Column(name = "content_snapshot", columnDefinition = "text")
    private String contentSnapshot;

    @Column(name = "creator_signed_at")
    private Instant creatorSignedAt;

    @Column(name = "listener_signed_at")
    private Instant listenerSignedAt;

    @Column(name = "terminated_at")
    private Instant terminatedAt;

    @PrePersist
    private void assignId() { if (id == null) id = UUID.randomUUID(); }

    public UUID getId() { return id; }
    public SeriesRequest getRequest() { return request; }
    public void setRequest(SeriesRequest value) { request = value; }
    public UUID getIdempotencyKey() { return idempotencyKey; }
    public void setIdempotencyKey(UUID value) { idempotencyKey = value; }
    public Contract getContract() { return contract; }
    public void setContract(Contract value) { contract = value; }
    public BigDecimal getBudget() { return budget; }
    public void setBudget(BigDecimal value) { budget = value; }
    public BigDecimal getRemaining() { return remaining; }
    public void setRemaining(BigDecimal value) { remaining = value; }
    public String getProductType() { return productType; }
    public void setProductType(String value) { productType = value; }
    public String getFileFormat() { return fileFormat; }
    public void setFileFormat(String value) { fileFormat = value; }
    public String getDurationDescription() { return durationDescription; }
    public void setDurationDescription(String value) { durationDescription = value; }
    public String getAcceptanceCriteria() { return acceptanceCriteria; }
    public void setAcceptanceCriteria(String value) { acceptanceCriteria = value; }
    public boolean isAutoAcceptEnabled() { return autoAcceptEnabled; }
    public void setAutoAcceptEnabled(boolean value) { autoAcceptEnabled = value; }
    public Integer getContractVersion() { return contractVersion; }
    public void setContractVersion(Integer value) { contractVersion = value; }
    public String getContentHash() { return contentHash; }
    public void setContentHash(String value) { contentHash = value; }
    public String getContentSnapshot() { return contentSnapshot; }
    public void setContentSnapshot(String value) { contentSnapshot = value; }
    public Instant getCreatorSignedAt() { return creatorSignedAt; }
    public void setCreatorSignedAt(Instant value) { creatorSignedAt = value; }
    public Instant getListenerSignedAt() { return listenerSignedAt; }
    public void setListenerSignedAt(Instant value) { listenerSignedAt = value; }
    public Instant getTerminatedAt() { return terminatedAt; }
    public void setTerminatedAt(Instant value) { terminatedAt = value; }
}
