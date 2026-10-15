package com.prmteam7.podcasthistory.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateDisputeRequest(@NotBlank @Size(max = 5000) String reason) {
}
