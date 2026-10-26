package com.prmteam7.podcasthistory.dto.request;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.math.BigDecimal;

@JsonIgnoreProperties(ignoreUnknown = true)
public record SepayWebhookRequest(
    String code, String transferType, BigDecimal transferAmount, String referenceCode) {}
