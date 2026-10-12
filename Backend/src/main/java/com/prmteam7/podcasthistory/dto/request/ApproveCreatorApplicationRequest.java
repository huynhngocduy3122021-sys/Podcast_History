package com.prmteam7.podcasthistory.dto.request;

import jakarta.validation.constraints.Size;

public record ApproveCreatorApplicationRequest(
        @Size(max = 2000) String note) {
}
