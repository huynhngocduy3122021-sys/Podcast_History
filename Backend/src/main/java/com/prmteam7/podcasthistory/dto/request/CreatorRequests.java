package com.prmteam7.podcasthistory.dto.request;

import java.util.UUID;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public final class CreatorRequests {

    private CreatorRequests() {
    }

    public record SeriesWrite(
            @NotNull UUID categoryId,
            @NotBlank @Size(max = 200) String title,
            @NotBlank @Size(max = 220) String slug,
            @Size(max = 10000) String description,
            @Size(max = 2000) String coverUrl) {
    }

    public record PodcastWrite(
            @NotNull UUID categoryId,
            @NotBlank @Size(max = 220) String title,
            @NotBlank @Size(max = 240) String slug,
            @Size(max = 10000) String description,
            @Size(max = 2000) String thumbnailUrl,
            @NotNull @Min(1) @Max(86400) Integer durationSeconds,
            @Min(1) Integer episodeNumber,
            @NotNull Boolean exclusive) {
    }

    public record SeriesAssignment(@NotNull UUID seriesId) {
    }

    public record ReviewNote(@Size(max = 5000) String note) {
    }
}
