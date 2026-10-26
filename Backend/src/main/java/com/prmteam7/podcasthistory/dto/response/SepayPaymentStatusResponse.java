package com.prmteam7.podcasthistory.dto.response;

import java.util.UUID;

public record SepayPaymentStatusResponse(
    UUID paymentId, String paymentStatus, UUID subscriptionId, String subscriptionStatus) {}
