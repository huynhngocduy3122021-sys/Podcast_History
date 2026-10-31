package com.prmteam7.podcasthistory.service;

import java.util.Map;
import java.util.UUID;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

/** Publishes non-persisted realtime events over the authenticated STOMP broker. */
@Component
public class RealtimeEventPublisher {
  private final SimpMessagingTemplate messaging;

  public RealtimeEventPublisher(SimpMessagingTemplate messaging) {
    this.messaging = messaging;
  }

  public void publishTopic(String destination, String type, Object data) {
    messaging.convertAndSend(destination, (Object) Map.of("type", type, "data", data));
  }

  public void publishUser(UUID userId, String type, Object data) {
    messaging.convertAndSendToUser(
        userId.toString(), "/queue/realtime", Map.of("type", type, "data", data));
  }

  public void publishApiChange(UUID userId, String type, Object data) {
    messaging.convertAndSendToUser(
        userId.toString(), "/queue/api-changes", Map.of("type", type, "data", data));
  }
}
