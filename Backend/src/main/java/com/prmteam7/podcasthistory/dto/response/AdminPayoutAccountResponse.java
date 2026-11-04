package com.prmteam7.podcasthistory.dto.response;

import java.util.UUID;

public record AdminPayoutAccountResponse(
        UUID payoutAccountId,
        UUID creatorProfileId,
        String channelName,
        String creatorName,
        String creatorEmail,
        String payoutMethod,
        String accountReference,
        String accountMasked,
        String currency,
        boolean verified,
        boolean active) {
}
