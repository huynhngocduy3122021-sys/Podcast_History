package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.util.UUID;

public record MilestoneResponse(
        UUID milestoneId,
        String name,
        String description,
        int order,
        BigDecimal amount,
        String currency,
        String status,
        UUID paymentId) {
}
