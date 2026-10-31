package com.prmteam7.podcasthistory.dto.response;

import java.time.Instant;
import java.util.UUID;

public record SeriesRequestMessageResponse(
        UUID messageId,
        UUID senderId,
        String senderName,
        String content,
        Instant createdAt) {
}
