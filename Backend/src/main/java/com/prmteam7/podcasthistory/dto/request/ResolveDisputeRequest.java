package com.prmteam7.podcasthistory.dto.request;

import com.prmteam7.podcasthistory.enums.MilestoneDisputeDecision;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ResolveDisputeRequest(
        @NotNull MilestoneDisputeDecision decision,
        @NotBlank @Size(max = 5000) String note) {
}
