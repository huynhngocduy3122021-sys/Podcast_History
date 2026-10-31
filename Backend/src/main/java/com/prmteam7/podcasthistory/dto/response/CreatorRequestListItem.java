package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record CreatorRequestListItem(
        UUID requestId,
        UUID listenerId,
        UUID creatorProfileId,
        String title,
        String description,
        BigDecimal proposedBudget,
        String currency,
        String status,
        String flowType,
        String productType,
        UUID contractId,
        String contractStatus,
        Instant createdAt,
        Instant respondedAt,
        String listenerName,
        String listenerAvatarUrl,
        String creatorChannelName,
        String creatorAvatarUrl) {}
