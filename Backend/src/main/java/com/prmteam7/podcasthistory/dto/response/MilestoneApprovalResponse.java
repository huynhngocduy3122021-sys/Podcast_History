package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.util.UUID;

public record MilestoneApprovalResponse(
        UUID milestoneId,
        String milestoneStatus,
        UUID paymentId,
        String paymentStatus,
        BigDecimal amount,
        String currency,
        String message,
        BigDecimal creatorNet,
        BigDecimal platformFee,
        BigDecimal remainingHeld) {
    public MilestoneApprovalResponse(UUID milestoneId, String milestoneStatus, UUID paymentId,
            String paymentStatus, BigDecimal amount, String currency, String message) {
        this(milestoneId, milestoneStatus, paymentId, paymentStatus, amount, currency, message,
                null, null, null);
    }
}
