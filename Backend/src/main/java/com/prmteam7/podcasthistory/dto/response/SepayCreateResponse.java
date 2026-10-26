package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.util.UUID;

public record SepayCreateResponse(
    UUID paymentId,
    String paymentCode,
    BigDecimal amount,
    String currency,
    String accountNumber,
    String bank,
    String qrUrl) {}
