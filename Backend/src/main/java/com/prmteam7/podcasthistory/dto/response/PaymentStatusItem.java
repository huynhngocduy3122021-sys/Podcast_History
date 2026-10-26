package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record PaymentStatusItem(
    UUID paymentId,
    UUID subscriptionId,
    String paymentCode,
    BigDecimal amount,
    String currency,
    String paymentStatus,
    String subscriptionStatus,
    Instant paidAt,
    Instant expiresAt) {}
