package com.prmteam7.podcasthistory.dto.response;

import java.util.List;

public record SeriesRequestDecisionResponse(
        SeriesRequestResponse request,
        String responseText,
        List<MilestoneResponse> milestones) {
}
