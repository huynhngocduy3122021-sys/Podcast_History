package com.prmteam7.podcasthistory.service;

import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import com.prmteam7.podcasthistory.dto.response.AdminResponses.NotificationItem;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.messaging.simp.SimpMessagingTemplate;

class NotificationRealtimePublisherTest {
    @Test
    void storedNotificationAlsoInvalidatesRecipientData() {
        SimpMessagingTemplate messaging = mock(SimpMessagingTemplate.class);
        RealtimeEventPublisher apiChanges = mock(RealtimeEventPublisher.class);
        NotificationRealtimePublisher publisher = new NotificationRealtimePublisher(
                mock(ApplicationEventPublisher.class), messaging, apiChanges);
        UUID userId = UUID.randomUUID();
        UUID notificationId = UUID.randomUUID();
        NotificationItem item = new NotificationItem(notificationId, "DISPUTE_CONFIRM_REQUIRED",
                "Tranh chấp", "Cần xác nhận", false, Instant.now(), null, null);

        publisher.send(new NotificationRealtimePublisher.NotificationRealtimeEvent(userId, item));

        verify(messaging).convertAndSendToUser(userId.toString(),
                NotificationRealtimePublisher.DESTINATION, item);
        verify(apiChanges).publishApiChange(eq(userId), eq("NOTIFICATION_CHANGED"),
                argThat(data -> notificationId.equals(((Map<?, ?>) data).get("notificationId"))));
    }
}
