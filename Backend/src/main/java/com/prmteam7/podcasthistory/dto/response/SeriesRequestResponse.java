package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record SeriesRequestResponse(
        UUID requestId,
        UUID listenerId,
        UUID creatorProfileId,
        String creatorChannelName,
        String title,
        String description,
        BigDecimal proposedBudget,
        String currency,
        String status,
        Instant createdAt,
        Instant respondedAt) {
}
