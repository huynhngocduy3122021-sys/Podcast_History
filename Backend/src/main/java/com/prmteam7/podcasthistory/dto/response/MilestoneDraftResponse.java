package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record MilestoneDraftResponse(UUID draftId, UUID milestoneId, int draftNumber,
        String status, String contentType, String note, String aiLabel,
        String aiRecommendation, BigDecimal aiConfidence, String aiReason,
        String errorMessage, Instant createdAt, Instant reviewedAt, Instant deliveredAt) {}
