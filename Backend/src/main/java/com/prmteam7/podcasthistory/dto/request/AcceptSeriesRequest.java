package com.prmteam7.podcasthistory.dto.request;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

public record AcceptSeriesRequest(
        @NotBlank @Size(max = 5000) String responseText,
        @NotEmpty @Size(max = 30) List<@Valid MilestoneOffer> milestones) {
}
