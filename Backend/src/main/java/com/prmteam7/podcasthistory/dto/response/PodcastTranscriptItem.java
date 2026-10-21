package com.prmteam7.podcasthistory.dto.response;

import java.time.Instant;
import java.util.UUID;
import tools.jackson.databind.JsonNode;

public record PodcastTranscriptItem(
        UUID transcriptId, UUID podcastId, String mediaKey, String status, String language,
        String modelName, String fullText, JsonNode segments, String errorMessage,
        Instant processedAt, boolean current) {}
