package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record WithdrawalResponse(
        UUID withdrawalRequestId,
        BigDecimal amount,
        String currency,
        String payoutMethod,
        String payoutAccountMasked,
        String providerReference,
        String status,
        Instant requestedAt,
        Instant processedAt,
        String note) {
}
