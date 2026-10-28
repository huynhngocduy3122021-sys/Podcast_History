package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record CheckoutHistoryItem(
    UUID checkoutId,
    String purpose,
    String paymentCode,
    BigDecimal amount,
    String currency,
    String status,
    Instant createdAt,
    Instant paidAt,
    Instant expiresAt,
    String providerTransactionId) {}
