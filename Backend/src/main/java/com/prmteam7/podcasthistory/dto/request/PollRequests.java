package com.prmteam7.podcasthistory.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class PollRequests {
    private PollRequests() {}

    @Schema(name = "PollWriteRequest", description = "Một poll có một câu hỏi và 2–20 option. Poll mới là DRAFT; seriesId và podcastId đều không bắt buộc.")
    public record Write(
            @NotBlank @Size(max = 5000) String question,
            @NotNull @Size(min = 2, max = 20) List<@NotBlank @Size(max = 300) String> options,
            @Schema(description = "Series trong kênh của CC. Bỏ trường hoặc gửi null nếu không gắn series.", nullable = true)
            UUID seriesId,
            @Schema(description = "Podcast trong kênh của CC. Bỏ trường hoặc gửi null nếu không gắn podcast.", nullable = true)
            UUID podcastId,
            Instant startsAt,
            Instant endsAt) {}

    @Schema(name = "PollAnswerRequest")
    public record Answer(@NotNull UUID optionId) {}
}
