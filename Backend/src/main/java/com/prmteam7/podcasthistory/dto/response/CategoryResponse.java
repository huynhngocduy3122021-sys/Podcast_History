package com.prmteam7.podcasthistory.dto.response;

import java.time.Instant;
import java.util.UUID;

public record CategoryResponse(
        UUID categoryId,
        String name,
        String slug,
        String description,
        Boolean active,
        Instant createdAt,
        Instant updatedAt) {
}
