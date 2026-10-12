package com.prmteam7.podcasthistory.dto.response;

import java.time.Instant;
import java.util.UUID;

public record CreatorApplicationResponse(
        UUID applicationId,
        UUID applicantUserId,
        String username,
        String email,
        String channelName,
        String introduction,
        String portfolioUrl,
        String status,
        String reviewNote,
        Instant submittedAt,
        Instant reviewedAt) {
}
