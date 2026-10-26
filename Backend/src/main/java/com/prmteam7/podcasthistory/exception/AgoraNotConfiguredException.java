package com.prmteam7.podcasthistory.exception;

public class AgoraNotConfiguredException extends RuntimeException {
  public AgoraNotConfiguredException() {
    super("Agora chưa được cấu hình. Hãy điền AGORA_APP_ID và AGORA_APP_CERTIFICATE trong Backend/.env.");
  }
}
