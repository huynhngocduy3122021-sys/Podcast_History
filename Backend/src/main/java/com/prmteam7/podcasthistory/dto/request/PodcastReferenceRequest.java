package com.prmteam7.podcasthistory.dto.request;

import com.prmteam7.podcasthistory.enums.PodcastReferenceType;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record PodcastReferenceRequest(
        @NotNull PodcastReferenceType referenceType,
        @NotBlank @Size(max = 300) String title,
        @Size(max = 200) String author,
        @Size(max = 200) String publisher,
        @Min(1) @Max(9999) Integer publishedYear,
        @Size(max = 2000) @Pattern(regexp = "(?i)^https?://[^\\s]+$",
                message = "URL nguồn phải bắt đầu bằng http:// hoặc https://") String url,
        @Size(max = 10000) String citationText) {
}
