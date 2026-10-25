package com.prmteam7.podcasthistory.config;

import com.prmteam7.podcasthistory.exception.AgoraNotConfiguredException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class AgoraProperties {
  private final String appId;
  private final String appCertificate;
  private final int tokenTtlSeconds;

  public AgoraProperties(
      @Value("${agora.app-id:}") String appId,
      @Value("${agora.app-certificate:}") String appCertificate,
      @Value("${agora.token-ttl-seconds:3600}") int tokenTtlSeconds) {
    this.appId = appId == null ? "" : appId.trim();
    this.appCertificate = appCertificate == null ? "" : appCertificate.trim();
    if (tokenTtlSeconds < 60 || tokenTtlSeconds > 86400) {
      throw new IllegalArgumentException("AGORA_TOKEN_TTL_SECONDS phải từ 60 đến 86400 giây.");
    }
    this.tokenTtlSeconds = tokenTtlSeconds;
  }

  public void requireConfigured() {
    if (!appId.matches("[0-9a-fA-F]{32}")
        || !appCertificate.matches("[0-9a-fA-F]{32}")) {
      throw new AgoraNotConfiguredException();
    }
  }

  public String appId() { return appId; }
  public String appCertificate() { return appCertificate; }
  public int tokenTtlSeconds() { return tokenTtlSeconds; }
}
