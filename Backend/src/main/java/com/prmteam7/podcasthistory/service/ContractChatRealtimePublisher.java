package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.response.ContractChatItem;
import java.util.Map;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class ContractChatRealtimePublisher {
    private final ApplicationEventPublisher events;
    private final SimpMessagingTemplate messaging;

    public ContractChatRealtimePublisher(ApplicationEventPublisher events, SimpMessagingTemplate messaging) {
        this.events = events;
        this.messaging = messaging;
    }

    public void publish(UUID listenerId, UUID creatorId, ContractChatItem item) {
        events.publishEvent(new Created(listenerId, creatorId, item));
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void send(Created event) {
        Object payload = Map.of("type", "CONTRACT_CHAT_MESSAGE", "data", event.item());
        messaging.convertAndSendToUser(event.listenerId().toString(), "/queue/contract-chat", payload);
        messaging.convertAndSendToUser(event.creatorId().toString(), "/queue/contract-chat", payload);
    }

    public record Created(UUID listenerId, UUID creatorId, ContractChatItem item) {}
}
