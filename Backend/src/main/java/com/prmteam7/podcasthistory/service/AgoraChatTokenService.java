package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.config.AgoraProperties;
import com.prmteam7.podcasthistory.dto.response.LivestreamResponses.ChatJoin;
import com.prmteam7.podcasthistory.exception.AgoraNotConfiguredException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.Livestream;
import io.agora.rtm.RtmTokenBuilder2;
import java.time.Instant;
import org.springframework.stereotype.Service;

@Service
public class AgoraChatTokenService {
  private final AgoraProperties properties;

  public AgoraChatTokenService(AgoraProperties properties) {
    this.properties = properties;
  }

  public ChatJoin issue(Livestream live, AppUser user) {
    properties.requireConfigured();
    String userId = user.getUserId().toString().replace("-", "");
    int ttl = properties.tokenTtlSeconds();
    String token = new RtmTokenBuilder2().buildToken(
        properties.appId(), properties.appCertificate(), userId, ttl);
    if (token == null || token.isBlank()) throw new AgoraNotConfiguredException();
    return new ChatJoin(live.getLivestreamId(), properties.appId(),
        "chat_" + live.getStreamReference(), userId, user.getDisplayName(), token,
        Instant.now().plusSeconds(ttl));
  }
}
