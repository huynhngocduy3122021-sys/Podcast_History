package com.prmteam7.podcasthistory.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;

public final class LivestreamRequests {
  private LivestreamRequests() {}

  public record Create(
      @NotBlank @Size(max = 220) String title,
      @Size(max = 10000) String description,
      Instant scheduledAt) {}
}
