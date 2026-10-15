package com.prmteam7.podcasthistory.dto.response;

import java.util.UUID;

public record PayoutAccountResponse(
        UUID payoutAccountId,
        UUID creatorProfileId,
        String payoutMethod,
        String accountMasked,
        String currency,
        boolean verified,
        boolean active) {
}
