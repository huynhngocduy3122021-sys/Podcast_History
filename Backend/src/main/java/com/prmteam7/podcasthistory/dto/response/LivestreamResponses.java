package com.prmteam7.podcasthistory.dto.response;

import java.time.Instant;
import java.util.UUID;

public final class LivestreamResponses {
  private LivestreamResponses() {}

  public record Item(
      UUID livestreamId,
      UUID creatorId,
      String creatorChannelName,
      String title,
      String description,
      String status,
      Instant scheduledAt,
      Instant startedAt,
      Instant endedAt,
      Instant createdAt,
      Instant updatedAt) {}

  public record AgoraJoin(
      UUID livestreamId,
      String appId,
      String channelName,
      String userAccount,
      String role,
      String token,
      Instant expiresAt) {}
}
