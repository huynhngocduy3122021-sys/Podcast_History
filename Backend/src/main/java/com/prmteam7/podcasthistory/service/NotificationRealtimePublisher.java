package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.response.AdminResponses.NotificationItem;
import com.prmteam7.podcasthistory.model.Notification;
import java.util.UUID;
import java.util.Map;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/** Publishes persisted notifications to the recipient's STOMP user queue. */
@Component
public class NotificationRealtimePublisher {
  public static final String DESTINATION = "/queue/notifications";

  private final ApplicationEventPublisher events;
  private final SimpMessagingTemplate messaging;
  private final RealtimeEventPublisher apiChanges;

  public NotificationRealtimePublisher(
      ApplicationEventPublisher events, SimpMessagingTemplate messaging,
      RealtimeEventPublisher apiChanges) {
    this.events = events;
    this.messaging = messaging;
    this.apiChanges = apiChanges;
  }

  public void publish(Notification notification) {
    if (notification == null
        || notification.getUser() == null
        || notification.getUser().getUserId() == null) {
      return;
    }
    NotificationItem item =
        new NotificationItem(
            notification.getNotificationId(),
            notification.getNotificationType(),
            notification.getTitle(),
            notification.getMessage(),
            Boolean.TRUE.equals(notification.getIsRead()),
            notification.getCreatedAt(),
            notification.getReadAt(),
            notification.getPayload());
    events.publishEvent(new NotificationRealtimeEvent(notification.getUser().getUserId(), item));
  }

  @TransactionalEventListener(
      phase = TransactionPhase.AFTER_COMMIT,
      fallbackExecution = true)
  public void send(NotificationRealtimeEvent event) {
    messaging.convertAndSendToUser(
        event.userId().toString(), DESTINATION, event.notification());
    apiChanges.publishApiChange(event.userId(), "NOTIFICATION_CHANGED", Map.of(
        "notificationId", event.notification().notificationId(),
        "notificationType", event.notification().type()));
  }

  public record NotificationRealtimeEvent(UUID userId, NotificationItem notification) {}
}
