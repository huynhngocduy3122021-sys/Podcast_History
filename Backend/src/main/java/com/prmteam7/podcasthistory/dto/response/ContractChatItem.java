package com.prmteam7.podcasthistory.dto.response;

import java.time.Instant;
import java.util.UUID;

public record ContractChatItem(UUID messageId, UUID requestId, UUID contractId,
                               UUID senderId, UUID clientMessageId,
                               String content, Instant createdAt) {}
