package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.response.PodcastTranscriptItem;
import com.prmteam7.podcasthistory.dto.response.PodcastTranscriptView;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.exception.ResourceForbiddenException;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.model.Podcast;
import com.prmteam7.podcasthistory.model.PodcastTranscript;
import com.prmteam7.podcasthistory.repository.PodcastRepository;
import com.prmteam7.podcasthistory.repository.PodcastTranscriptRepository;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import java.time.Instant;
import java.time.Duration;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import tools.jackson.databind.JsonNode;

@Service
public class PodcastTranscriptService {
    private static final org.slf4j.Logger LOG = org.slf4j.LoggerFactory.getLogger(PodcastTranscriptService.class);
    private final PodcastTranscriptRepository transcripts;
    private final PodcastRepository podcasts;
    private final AppUserRepository users;
    private final WhisperTranscriptionClient whisper;
    private final AdminSupportService support;
    private final ListenerFlowService listenerFlow;
    private final ApplicationEventPublisher events;

    public PodcastTranscriptService(PodcastTranscriptRepository transcripts, PodcastRepository podcasts,
            AppUserRepository users,
            WhisperTranscriptionClient whisper, AdminSupportService support,
            ListenerFlowService listenerFlow, ApplicationEventPublisher events) {
        this.transcripts = transcripts;
        this.podcasts = podcasts;
        this.users = users;
        this.whisper = whisper;
        this.support = support;
        this.listenerFlow = listenerFlow;
        this.events = events;
    }

    // Called within the upload transaction.
    public void enqueue(Podcast podcast) {
        PodcastTranscript transcript = transcripts
                .findByPodcast_PodcastIdAndMediaKey(podcast.getPodcastId(), podcast.getMediaUrl())
                .orElseGet(() -> {
                    PodcastTranscript item = new PodcastTranscript();
                    item.setPodcast(podcast);
                    item.setMediaKey(podcast.getMediaUrl());
                    return item;
                });
        if ("COMPLETED".equals(transcript.getStatus()) || "PROCESSING".equals(transcript.getStatus())) return;
        transcript.setStatus("PENDING");
        transcript.setErrorMessage(null);
        transcript.setFullText(null);
        transcript.setSegments(null);
        transcript.setProcessedAt(null);
        transcript.setProcessingStartedAt(null);
        transcripts.save(transcript);
        events.publishEvent(new Requested(transcript.getTranscriptId()));
    }

    @Transactional
    public PodcastTranscriptItem retry(UUID actor, UUID podcastId) {
        support.actor(actor, false);
        Podcast podcast = podcasts.findByPodcastId(podcastId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy podcast."));
        if (podcast.getMediaUrl() == null || podcast.getMediaUrl().isBlank())
            throw new ResourceConflictException("Podcast chưa có media.");
        transcripts.findByPodcast_PodcastIdAndMediaKey(podcastId, podcast.getMediaUrl())
                .filter(t -> "PROCESSING".equals(t.getStatus()))
                .filter(t -> t.getProcessingStartedAt() == null
                        || t.getProcessingStartedAt().isBefore(Instant.now().minus(Duration.ofMinutes(30))))
                .ifPresent(t -> {
                    t.setStatus("FAILED");
                    transcripts.save(t);
                });
        enqueue(podcast);
        return current(actor, podcastId);
    }

    @Transactional(readOnly = true)
    public PodcastTranscriptItem current(UUID actor, UUID podcastId) {
        support.actor(actor, false);
        Podcast podcast = podcasts.findByPodcastId(podcastId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy podcast."));
        return currentItem(podcast);
    }

    @Transactional(readOnly = true)
    public PodcastTranscriptView currentForViewer(UUID actor, UUID podcastId) {
        var user = users.findByUserId(actor)
                .filter(item -> Boolean.TRUE.equals(item.getIsActive()))
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản đang hoạt động."));
        String role = user.getRole() == null ? "" : user.getRole().getRoleCode();
        if ("CREATOR".equalsIgnoreCase(role)) {
            Podcast podcast = podcasts.findByPodcastId(podcastId)
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy podcast."));
            var profile = podcast.getProducerProfile();
            if (!profile.getUser().getUserId().equals(actor)
                    || !"APPROVED".equalsIgnoreCase(profile.getVerificationStatus())) {
                throw new ResourceNotFoundException("Không tìm thấy podcast thuộc kênh này.");
            }
            PodcastTranscript transcript = findCurrentTranscript(podcast);
            return view(podcastId, transcript, transcript.getErrorMessage());
        }
        if ("LISTENER".equalsIgnoreCase(role)) {
            listenerFlow.requireReferenceAccess(actor, podcastId);
            Podcast podcast = podcasts.findByPodcastId(podcastId)
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy podcast."));
            return completedView(podcast);
        }
        throw new ResourceForbiddenException("Chỉ chủ kênh hoặc Listener có quyền nghe được xem transcript.");
    }

    private PodcastTranscriptItem currentItem(Podcast podcast) {
        UUID podcastId = podcast.getPodcastId();
        PodcastTranscript transcript = findCurrentTranscript(podcast);
        return new PodcastTranscriptItem(transcript.getTranscriptId(), podcastId, transcript.getMediaKey(),
                transcript.getStatus(), transcript.getLanguage(), transcript.getModelName(),
                transcript.getFullText(), transcript.getSegments(), transcript.getErrorMessage(),
                transcript.getProcessedAt(), true);
    }

    private PodcastTranscriptView completedView(Podcast podcast) {
        PodcastTranscript transcript = findCurrentTranscript(podcast);
        if (!"COMPLETED".equals(transcript.getStatus())) {
            throw new ResourceNotFoundException("Podcast chưa có transcript hoàn tất.");
        }
        return view(podcast.getPodcastId(), transcript, null);
    }

    private PodcastTranscript findCurrentTranscript(Podcast podcast) {
        return transcripts.findByPodcast_PodcastIdAndMediaKey(podcast.getPodcastId(), podcast.getMediaUrl())
                .orElseThrow(() -> new ResourceNotFoundException("Podcast chưa có transcript."));
    }

    private PodcastTranscriptView view(UUID podcastId, PodcastTranscript transcript, String errorMessage) {
        return new PodcastTranscriptView(podcastId, transcript.getStatus(), transcript.getLanguage(),
                transcript.getModelName(), transcript.getFullText(), transcript.getSegments(),
                errorMessage, transcript.getProcessedAt());
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async
    public void onRequested(Requested event) {
        PodcastTranscript transcript = transcripts.findById(event.id()).orElse(null);
        if (transcript == null || !"PENDING".equals(transcript.getStatus())) return;
        Instant started = Instant.now();
        if (transcripts.claim(event.id(), started) == 0) return;
        transcript.setStatus("PROCESSING");
        transcript.setProcessingStartedAt(started);
        try {
            JsonNode output = whisper.transcribe(transcript.getMediaKey());
            transcript.setFullText(output.path("fullText").asText());
            transcript.setSegments(output.path("segments"));
            transcript.setLanguage(output.path("language").asText());
            String model = output.path("modelName").asText();
            if (!model.isBlank()) transcript.setModelName(model);
            transcript.setStatus("COMPLETED");
        } catch (Exception exception) {
            if (exception instanceof InterruptedException) Thread.currentThread().interrupt();
            transcript.setStatus("FAILED");
            String message = exception.getMessage() == null ? exception.getClass().getSimpleName() : exception.getMessage();
            transcript.setErrorMessage(message.substring(0, Math.min(message.length(), 500)));
        }
        transcript.setProcessedAt(Instant.now());
        try {
            transcripts.saveAndFlush(transcript);
        } catch (RuntimeException failure) {
            LOG.error("Không thể lưu kết quả Whisper cho transcript {}", event.id(), failure);
            String detail = failure.getMessage() == null ? failure.getClass().getSimpleName() : failure.getMessage();
            try {
                transcripts.failPersistence(event.id(), detail.substring(0, Math.min(detail.length(), 500)), Instant.now());
            } catch (RuntimeException recoveryFailure) {
                LOG.error("Không thể đánh dấu transcript {} là FAILED", event.id(), recoveryFailure);
                return;
            }
        }
        events.publishEvent(new Finished(transcript.getPodcast().getPodcastId(), transcript.getMediaKey()));
    }

    public record Requested(UUID id) {}
    public record Finished(UUID podcastId, String mediaKey) {}
}
