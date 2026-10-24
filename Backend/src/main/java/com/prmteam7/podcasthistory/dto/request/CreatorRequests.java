package com.prmteam7.podcasthistory.dto.request;

import java.util.UUID;
import com.fasterxml.jackson.annotation.JsonIgnore;
import com.prmteam7.podcasthistory.enums.PodcastVisibility;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.AssertTrue;

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
            @Size(max = 10000) String description,
            @Size(max = 2000) String thumbnailUrl,
            @NotNull @Min(1) @Max(86400) Integer durationSeconds,
            @Min(1) Integer episodeNumber,
            @Schema(description = "Quyền xem: PUBLIC hoặc MEMBERS_ONLY. Cần chọn visibility hoặc exclusive.")
            PodcastVisibility visibility,
            @Schema(description = "Tương thích client cũ: true là MEMBERS_ONLY, false là PUBLIC", deprecated = true)
            Boolean exclusive) {

        @JsonIgnore
        @Schema(hidden = true)
        @AssertTrue(message = "Chọn visibility PUBLIC/MEMBERS_ONLY; nếu gửi cả exclusive thì hai giá trị phải khớp.")
        public boolean isVisibilitySelectionValid() {
            return (visibility != null || exclusive != null)
                    && (visibility == null || exclusive == null || visibility.isExclusive() == exclusive);
        }

        public PodcastVisibility resolvedVisibility() {
            return visibility != null ? visibility : PodcastVisibility.fromExclusive(exclusive);
        }
    }

    public record SeriesAssignment(@NotNull UUID seriesId) {
    }

    public record ReviewNote(@Size(max = 5000) String note) {
    }
}
