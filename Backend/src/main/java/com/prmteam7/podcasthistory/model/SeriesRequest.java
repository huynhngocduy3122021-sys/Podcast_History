package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "\"Series_request\"", indexes = {
        @Index(name = "idx_series_request_user_id", columnList = "user_id"),
        @Index(name = "idx_series_request_producer_profile_id", columnList = "producer_profile_id")
    })
public class SeriesRequest extends UpdatedEntity {
    @Id
    @Column(name = "series_request_id", nullable = false, updatable = false)
    private UUID seriesRequestId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "producer_profile_id", nullable = false)
    private ProducerProfile producerProfile;

    @Column(name = "requested_title", nullable = false, length = 220)
    private String requestedTitle;

    @Column(name = "description", nullable = false, columnDefinition = "text")
    private String description;

    @Column(name = "request_fee", nullable = false, precision = 12, scale = 2)
    private BigDecimal requestFee;

    @JdbcTypeCode(SqlTypes.CHAR)
    @Column(name = "currency", nullable = false, length = 3, columnDefinition = "char(3)")
    private String currency;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    @Column(name = "responded_at", nullable = true)
    private Instant respondedAt;

    public SeriesRequest() {
    }

    @PrePersist
    private void assignId() {
        if (seriesRequestId == null) {
            seriesRequestId = UUID.randomUUID();
        }
    }

    public UUID getSeriesRequestId() {
        return seriesRequestId;
    }

    public void setSeriesRequestId(UUID seriesRequestId) {
        this.seriesRequestId = seriesRequestId;
    }

    public AppUser getUser() {
        return user;
    }

    public void setUser(AppUser user) {
        this.user = user;
    }

    public ProducerProfile getProducerProfile() {
        return producerProfile;
    }

    public void setProducerProfile(ProducerProfile producerProfile) {
        this.producerProfile = producerProfile;
    }

    public String getRequestedTitle() {
        return requestedTitle;
    }

    public void setRequestedTitle(String requestedTitle) {
        this.requestedTitle = requestedTitle;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public BigDecimal getRequestFee() {
        return requestFee;
    }

    public void setRequestFee(BigDecimal requestFee) {
        this.requestFee = requestFee;
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

    public Instant getRespondedAt() {
        return respondedAt;
    }

    public void setRespondedAt(Instant respondedAt) {
        this.respondedAt = respondedAt;
    }

}
