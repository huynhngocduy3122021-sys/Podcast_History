package com.prmteam7.podcasthistory.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreatorApplicationRequest(
        @NotBlank @Size(max = 150) String channelName,
        @NotBlank @Size(max = 5000) String introduction,
        @Size(max = 2000) String portfolioUrl) {
}
