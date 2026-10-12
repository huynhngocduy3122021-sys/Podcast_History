package com.prmteam7.podcasthistory.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record RejectCreatorApplicationRequest(
        @NotBlank @Size(max = 2000) String note) {
}
