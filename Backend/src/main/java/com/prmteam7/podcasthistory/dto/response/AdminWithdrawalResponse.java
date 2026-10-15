package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record AdminWithdrawalResponse(
        UUID withdrawalRequestId,
        UUID creatorProfileId,
        BigDecimal amount,
        String currency,
        String payoutMethod,
        String payoutAccountMasked,
        String payoutAccountReference,
        String status,
        Instant requestedAt,
        String note) {
}
