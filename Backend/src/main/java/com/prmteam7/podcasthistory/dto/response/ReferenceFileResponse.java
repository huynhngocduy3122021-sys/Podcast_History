package com.prmteam7.podcasthistory.dto.response;

import java.time.Instant;
import java.util.UUID;

public record ReferenceFileResponse(UUID referenceId, String downloadUrl, Instant expiresAt) {
}
