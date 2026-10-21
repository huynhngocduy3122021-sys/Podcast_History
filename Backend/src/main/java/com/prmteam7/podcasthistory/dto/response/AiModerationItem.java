package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import tools.jackson.databind.JsonNode;

public record AiModerationItem(
        UUID moderationResultId,
        UUID podcastId,
        UUID transcriptId,
        String transcriptHash,
        String modelName,
        String modelVersion,
        String status,
        String overallLabel,
        String recommendation,
        BigDecimal confidenceScore,
        String reason,
        JsonNode rawResult,
        String sourceHash,
        String mediaKey,
        String errorMessage,
        Instant processedAt,
        boolean current) {
}
