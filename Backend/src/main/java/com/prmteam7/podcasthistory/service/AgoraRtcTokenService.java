package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.config.AgoraProperties;
import com.prmteam7.podcasthistory.dto.response.LivestreamResponses.AgoraJoin;
import com.prmteam7.podcasthistory.exception.AgoraNotConfiguredException;
import com.prmteam7.podcasthistory.model.Livestream;
import io.agora.media.RtcTokenBuilder2;
import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class AgoraRtcTokenService {
  private final AgoraProperties properties;

  public AgoraRtcTokenService(AgoraProperties properties) {
    this.properties = properties;
  }

  public void requireConfigured() {
    properties.requireConfigured();
  }

  public AgoraJoin issue(Livestream livestream, UUID userId, boolean host) {
    properties.requireConfigured();
    String channel = livestream.getStreamReference();
    String account = userId.toString();
    int ttl = properties.tokenTtlSeconds();
    String token = new RtcTokenBuilder2().buildTokenWithUserAccount(
        properties.appId(), properties.appCertificate(), channel, account,
        host ? RtcTokenBuilder2.Role.ROLE_PUBLISHER : RtcTokenBuilder2.Role.ROLE_SUBSCRIBER,
        ttl, ttl);
    if (token == null || token.isBlank()) throw new AgoraNotConfiguredException();
    return new AgoraJoin(livestream.getLivestreamId(), properties.appId(), channel, account,
        host ? "host" : "audience", token, Instant.now().plusSeconds(ttl));
  }
}
