package com.prmteam7.podcasthistory.dto.request;

import com.prmteam7.podcasthistory.enums.DisputeDecision;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ResolveDisputeRequest(
        @NotNull DisputeDecision decision,
        @NotBlank @Size(max = 5000) String note) {
}
