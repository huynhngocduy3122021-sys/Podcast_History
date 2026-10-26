package com.prmteam7.podcasthistory.dto.request;

import java.math.BigDecimal;

public record SepayWebhookRequest(
    Long id,
    String transferType,
    BigDecimal transferAmount,
    String code,
    String content) {}
