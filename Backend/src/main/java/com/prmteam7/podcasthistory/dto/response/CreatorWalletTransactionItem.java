package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record CreatorWalletTransactionItem(
        UUID transactionId,
        String type,
        String direction,
        BigDecimal amount,
        String currency,
        String status,
        String referenceCode,
        BigDecimal balanceAfter,
        BigDecimal heldBalanceAfter,
        Instant createdAt) {}
