package com.prmteam7.podcasthistory.dto.request;

import com.prmteam7.podcasthistory.enums.PayoutResult;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record RecordPayoutResultRequest(
        @NotNull PayoutResult result,
        @Size(max = 180) String providerReference,
        @Size(max = 5000) String note) {
}
