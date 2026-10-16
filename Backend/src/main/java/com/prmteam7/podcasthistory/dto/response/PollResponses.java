package com.prmteam7.podcasthistory.dto.response;

import com.prmteam7.podcasthistory.enums.PollStatus;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class PollResponses {
    private PollResponses() {}

    @Schema(name = "PollSummary")
    public record Summary(UUID pollId, UUID creatorProfileId, String channelName,
            UUID seriesId, UUID podcastId, String question, PollStatus status, Instant startsAt,
            Instant endsAt, boolean acceptingResponses, Instant createdAt, Instant updatedAt) {}

    @Schema(name = "PollOption")
    public record Option(UUID optionId, String text, int sortOrder) {}

    @Schema(name = "PollDetail")
    public record Detail(Summary poll, List<Option> options) {}

    @Schema(name = "PollResponse")
    public record Response(UUID responseId, UUID pollId, UUID userId,
            String displayName, UUID optionId, String optionText, Instant submittedAt) {}

    @Schema(name = "PollOptionResult")
    public record OptionResult(UUID optionId, String text, int sortOrder,
            long responseCount, double percentage) {}

    @Schema(name = "PollResults")
    public record Results(UUID pollId, String question, long totalResponses,
            List<OptionResult> options) {}
}
