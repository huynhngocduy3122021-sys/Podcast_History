package com.prmteam7.podcasthistory.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.util.UUID;

@Entity
@Table(name = "\"Contract\"", indexes = {
        @Index(name = "idx_contract_user_id", columnList = "user_id"),
        @Index(name = "idx_contract_producer_profile_id", columnList = "producer_profile_id")
    })
public class Contract extends UpdatedEntity {

    @jakarta.persistence.Id
    @Column(name = "contract_id", nullable = false, updatable = false)
    private UUID contractId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private AppUser user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "producer_profile_id", nullable = false)
    private ProducerProfile producerProfile;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "series_response_id", nullable = false, unique = true)
    private RequestResponse seriesResponse;

    @Column(name = "status", nullable = false, length = 30)
    private String status;

    public Contract() {
    }

    @PrePersist
    private void assignId() {
        if (contractId == null) {
            contractId = UUID.randomUUID();
        }
    }

    public UUID getContractId() {
        return contractId;
    }

    public void setContractId(UUID contractId) {
        this.contractId = contractId;
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

    public RequestResponse getSeriesResponse() {
        return seriesResponse;
    }

    public void setSeriesResponse(RequestResponse seriesResponse) {
        this.seriesResponse = seriesResponse;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }
}
