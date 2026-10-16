package com.prmteam7.podcasthistory.dto.response;

import java.time.Instant;
import java.util.UUID;

public record MilestoneSubmissionResponse(
        UUID submissionId,
        UUID milestoneId,
        int revisionNumber,
        String objectKey,
        String publicUrl,
        String contentType,
        String note,
        Instant submittedAt) {
}
