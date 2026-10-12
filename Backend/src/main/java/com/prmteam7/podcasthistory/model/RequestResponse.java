package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "\"Series_response\"", indexes = {
        @Index(name = "idx_request_response_series_request_id", columnList = "series_request_id")
    })
public class RequestResponse extends UpdatedEntity {
    @Id
    @Column(name = "series_response_id", nullable = false, updatable = false)
    private UUID requestResponseId;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "series_request_id", nullable = false)
    private SeriesRequest seriesRequest;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "producer_profile_id", nullable = false)
    private ProducerProfile producerProfile;

    @Column(name = "response_text", nullable = false, columnDefinition = "text")
    private String responseText;

    @Column(name = "response_status", nullable = false, length = 30)
    private String responseStatus;

    public RequestResponse() {
    }

    @PrePersist
    private void assignId() {
        if (requestResponseId == null) {
            requestResponseId = UUID.randomUUID();
        }
    }

    public UUID getRequestResponseId() {
        return requestResponseId;
    }

    public void setRequestResponseId(UUID requestResponseId) {
        this.requestResponseId = requestResponseId;
    }

    public SeriesRequest getSeriesRequest() {
        return seriesRequest;
    }

    public void setSeriesRequest(SeriesRequest seriesRequest) {
        this.seriesRequest = seriesRequest;
    }

    public ProducerProfile getProducerProfile() {
        return producerProfile;
    }

    public void setProducerProfile(ProducerProfile producerProfile) {
        this.producerProfile = producerProfile;
    }

    public String getResponseText() {
        return responseText;
    }

    public void setResponseText(String responseText) {
        this.responseText = responseText;
    }

    public String getResponseStatus() {
        return responseStatus;
    }

    public void setResponseStatus(String responseStatus) {
        this.responseStatus = responseStatus;
    }

}
