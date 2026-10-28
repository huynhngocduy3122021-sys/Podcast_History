package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record CheckoutPaymentView(UUID checkoutId, UUID creatorSubscriptionId,
    String purpose, String paymentCode, String qrImageUrl, BigDecimal amount,
    String currency, String status, Instant paidAt, Instant expiresAt) {}
