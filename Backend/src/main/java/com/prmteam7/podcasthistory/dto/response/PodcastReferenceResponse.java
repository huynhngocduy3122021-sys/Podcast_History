package com.prmteam7.podcasthistory.dto.response;

import java.time.Instant;
import java.util.UUID;

public record PodcastReferenceResponse(
        UUID referenceId, UUID podcastId, String referenceType, String title,
        String author, String publisher, Integer publishedYear, String url,
        String fileKey, String citationText, Instant createdAt) {
}
