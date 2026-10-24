package com.prmteam7.podcasthistory.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CategoryUpdateRequest(
        @NotBlank @Size(max = 120) String name,
        @NotBlank @Size(max = 140) String slug,
        @Size(max = 10000) String description,
        @NotNull Boolean active) {
}
