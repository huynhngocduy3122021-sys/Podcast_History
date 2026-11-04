package com.prmteam7.podcasthistory.service;

import java.io.IOException;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import com.prmteam7.podcasthistory.dto.response.ListenerResponses.CommentItem;

@Component
public class CommentRealtimeHub {

    private final ConcurrentHashMap<UUID, CopyOnWriteArrayList<SseEmitter>> listeners = new ConcurrentHashMap<>();
    private final RealtimeEventPublisher realtime;

    public CommentRealtimeHub(RealtimeEventPublisher realtime) {
        this.realtime = realtime;
    }

    public SseEmitter subscribe(UUID podcastId) {
        SseEmitter emitter = new SseEmitter(0L);
        CopyOnWriteArrayList<SseEmitter> podcastListeners = listeners.computeIfAbsent(
                podcastId, ignored -> new CopyOnWriteArrayList<>());
        podcastListeners.add(emitter);
        Runnable remove = () -> remove(podcastId, emitter);
        emitter.onCompletion(remove);
        emitter.onTimeout(remove);
        emitter.onError(ignored -> remove.run());
        try {
            emitter.send(SseEmitter.event().name("connected").data(podcastId));
        } catch (IOException exception) {
            remove.run();
            emitter.completeWithError(exception);
        }
        return emitter;
    }

    public void publish(UUID podcastId, CommentItem comment) {
        realtime.publishTopic("/topic/podcasts/" + podcastId + "/comments", "COMMENT_CREATED", comment);
        CopyOnWriteArrayList<SseEmitter> podcastListeners = listeners.get(podcastId);
        if (podcastListeners == null) {
            return;
        }
        for (SseEmitter emitter : podcastListeners) {
            try {
                emitter.send(SseEmitter.event().name("comment-created").data(comment));
            } catch (IOException exception) {
                remove(podcastId, emitter);
                emitter.completeWithError(exception);
            }
        }
    }

    private void remove(UUID podcastId, SseEmitter emitter) {
        CopyOnWriteArrayList<SseEmitter> podcastListeners = listeners.get(podcastId);
        if (podcastListeners != null) {
            podcastListeners.remove(emitter);
            if (podcastListeners.isEmpty()) {
                listeners.remove(podcastId, podcastListeners);
            }
        }
    }
}
