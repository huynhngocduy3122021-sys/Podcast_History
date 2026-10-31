package com.prmteam7.podcasthistory.dto.response;

import java.time.Instant;
import java.util.UUID;

public record DisputeResponse(
        UUID disputeId,
        UUID milestoneId,
        UUID raisedByUserId,
        String reason,
        String status,
        String decision,
        String resolutionNote,
        UUID reviewedByUserId,
        Instant createdAt,
        Instant resolvedAt,
        Instant responseDeadlineAt,
        Instant opponentConfirmedAt,
        String listenerWinAction) {
}
