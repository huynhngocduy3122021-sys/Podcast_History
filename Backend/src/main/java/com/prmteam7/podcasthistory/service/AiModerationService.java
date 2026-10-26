package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.response.AiModerationItem;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.model.AiModerationResult;
import com.prmteam7.podcasthistory.model.Podcast;
import com.prmteam7.podcasthistory.model.PodcastTranscript;
import com.prmteam7.podcasthistory.repository.AiModerationResultRepository;
import com.prmteam7.podcasthistory.repository.PodcastRepository;
import com.prmteam7.podcasthistory.repository.PodcastTranscriptRepository;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.event.EventListener;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import tools.jackson.databind.JsonNode;

@Service
public class AiModerationService {
    private final AiModerationResultRepository results;
    private final PodcastRepository podcasts;
    private final GeminiModerationClient gemini;
    private final AdminSupportService support;
    private final ApplicationEventPublisher events;
    private final PodcastTranscriptRepository transcripts;
    private final PodcastReviewService podcastReviews;

    public AiModerationService(AiModerationResultRepository results, PodcastRepository podcasts,
            GeminiModerationClient gemini, AdminSupportService support, ApplicationEventPublisher events,
            PodcastTranscriptRepository transcripts, PodcastReviewService podcastReviews) {
        this.results = results;
        this.podcasts = podcasts;
        this.gemini = gemini;
        this.support = support;
        this.events = events;
        this.transcripts = transcripts;
        this.podcastReviews = podcastReviews;
    }

    @Transactional
    public AiModerationItem retry(UUID actor, UUID podcastId) {
        support.actor(actor, false);
        Podcast podcast = podcasts.findByPodcastId(podcastId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy podcast."));
        if (!"PENDING_REVIEW".equalsIgnoreCase(podcast.getStatus())) {
            throw new ResourceConflictException("Podcast không ở trạng thái chờ duyệt.");
        }
        return enqueue(podcast);
    }

    // Called in the Creator submit transaction; publication runs only after commit.
    public AiModerationItem enqueue(Podcast podcast) {
        AiModerationResult result = new AiModerationResult();
        result.setPodcast(podcast);
        result.setModelName(gemini.model());
        result.setOverallLabel("PENDING");
        result.setStatus("PENDING");
        result.setSourceHash(hash(podcast));
        result.setMediaKey(podcast.getMediaUrl());
        transcripts.findByPodcast_PodcastIdAndMediaKey(podcast.getPodcastId(), podcast.getMediaUrl())
                .ifPresent(result::setTranscript);
        results.save(result);
        events.publishEvent(new Requested(result.getModerationResultId()));
        return item(result, true);
    }

    @Transactional(readOnly = true)
    public Page<AiModerationItem> history(UUID actor, UUID podcastId, int page, int size) {
        support.actor(actor, false);
        Podcast podcast = podcasts.findByPodcastId(podcastId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy podcast."));
        String currentHash = hash(podcast);
        String currentTranscriptHash = transcripts
                .findByPodcast_PodcastIdAndMediaKey(podcastId, podcast.getMediaUrl())
                .filter(t -> "COMPLETED".equals(t.getStatus()))
                .map(t -> hashText(t.getFullText())).orElse(null);
        return results.findAllByPodcast_PodcastIdOrderByCreatedAtDesc(
                podcastId, PageRequest.of(Math.max(0, page), Math.max(1, Math.min(size, 100))))
                .map(r -> item(r, currentHash.equals(r.getSourceHash())
                        && currentTranscriptHash != null
                        && currentTranscriptHash.equals(r.getTranscriptHash())));
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async
    public void onRequested(Requested event) {
        process(event.id());
    }

    @EventListener
    @Async
    public void onTranscriptFinished(PodcastTranscriptService.Finished event) {
        results.findAllByPodcast_PodcastIdAndStatusAndMediaKey(
                event.podcastId(), "PENDING", event.mediaKey()).forEach(r -> process(r.getModerationResultId()));
    }

    private void process(UUID id) {
        AiModerationResult result = results.findById(id).orElse(null);
        if (result == null || !"PENDING".equals(result.getStatus())) return;
        Podcast podcast = podcasts.findByPodcastId(result.getPodcast().getPodcastId()).orElse(null);
        if (podcast == null) return;
        if (!result.getSourceHash().equals(hash(podcast))) {
            finish(result, "SKIPPED", "STALE", "REVIEW", "Podcast đã thay đổi sau khi gửi duyệt.", null, null);
            return;
        }
        PodcastTranscript transcript = transcripts
                .findByPodcast_PodcastIdAndMediaKey(podcast.getPodcastId(), podcast.getMediaUrl())
                .orElse(null);
        if (transcript == null || "PENDING".equals(transcript.getStatus())
                || "PROCESSING".equals(transcript.getStatus())) return;
        if (results.claim(id) == 0) return;
        result.setStatus("PROCESSING");
        result.setTranscript(transcript);
        if ("COMPLETED".equals(transcript.getStatus()))
            result.setTranscriptHash(hashText(transcript.getFullText()));
        if ("FAILED".equals(transcript.getStatus())) {
            finish(result, "FAILED", "ERROR", "REVIEW",
                    "Không thể phiên âm media; cần Admin xử lý thủ công.", null, transcript.getErrorMessage());
            return;
        }
        if (!"COMPLETED".equals(transcript.getStatus()) || transcript.getFullText() == null
                || transcript.getFullText().isBlank()) {
            finish(result, "SKIPPED", "NO_SPEECH", "REVIEW",
                    "Không có lời nói để AI đánh giá; cần Admin nghe/xem thủ công.", null, null);
            return;
        }
        if (!gemini.configured()) {
            finish(result, "SKIPPED", "UNAVAILABLE", "REVIEW", "GEMINI_API_KEY chưa được cấu hình.", null, null);
            return;
        }
        try {
            var response = gemini.analyze(podcast.getTitle(), podcast.getDescription(),
                    timedTranscript(transcript));
            JsonNode output = response.output();
            result.setModelName(response.modelName());
            String label = allowed(output.path("label").asText(), "SAFE", "UNSAFE", "UNCERTAIN");
            String recommendation = allowed(output.path("recommendation").asText(), "APPROVE", "REJECT", "REVIEW");
            if (label == null || recommendation == null) {
                throw new IllegalArgumentException("Gemini trả nhãn kiểm duyệt không hợp lệ.");
            }
            String reason = output.path("reason").asText();
            if (reason.isBlank()) reason = "Gemini không cung cấp lý do.";
            finish(result, "COMPLETED", label, recommendation, reason, output, null);
        } catch (Exception exception) {
            if (exception instanceof InterruptedException) Thread.currentThread().interrupt();
            String message = exception.getMessage();
            String error = message == null ? exception.getClass().getSimpleName() : message;
            finish(result, "FAILED", "ERROR", "REVIEW", "AI không xử lý được; cần Admin duyệt thủ công.",
                    null, error.substring(0, Math.min(error.length(), 500)));
        }
        if ("COMPLETED".equals(result.getStatus()) && "SAFE".equals(result.getOverallLabel())
                && "APPROVE".equals(result.getRecommendation())) {
            podcastReviews.autoApprove(result.getModerationResultId());
        }
    }

    private void finish(AiModerationResult result, String status, String label, String recommendation,
            String reason, JsonNode raw, String error) {
        result.setStatus(status);
        result.setOverallLabel(label);
        result.setRecommendation(recommendation);
        result.setReason(reason);
        result.setRawResult(raw);
        result.setErrorMessage(error);
        result.setProcessedAt(Instant.now());
        results.save(result);
    }

    private String allowed(String value, String... choices) {
        for (String choice : choices) if (choice.equals(value)) return value;
        return null;
    }

    private AiModerationItem item(AiModerationResult r, boolean current) {
        return new AiModerationItem(r.getModerationResultId(), r.getPodcast().getPodcastId(),
                r.getTranscript() == null ? null : r.getTranscript().getTranscriptId(), r.getTranscriptHash(),
                r.getModelName(), r.getModelVersion(), r.getStatus(), r.getOverallLabel(),
                r.getRecommendation(), r.getConfidenceScore(), r.getReason(), r.getRawResult(),
                r.getSourceHash(), r.getMediaKey(), r.getErrorMessage(), r.getProcessedAt(), current);
    }

    public static String hash(Podcast podcast) {
        String source = String.join("\u001f",
                nullable(podcast.getTitle()), nullable(podcast.getDescription()),
                nullable(podcast.getMediaUrl()), nullable(podcast.getMediaType()),
                nullable(podcast.getThumbnailUrl()));
        return hashText(source);
    }

    public static String hashText(String source) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(nullable(source).getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException(exception);
        }
    }

    private static String nullable(String value) {
        return value == null ? "" : value;
    }

    private String timedTranscript(PodcastTranscript transcript) {
        if (transcript.getSegments() == null || !transcript.getSegments().isArray())
            return transcript.getFullText();
        StringBuilder text = new StringBuilder();
        for (JsonNode segment : transcript.getSegments()) {
            text.append('[').append(segment.path("start").asText()).append('-')
                    .append(segment.path("end").asText()).append("] ")
                    .append(segment.path("text").asText()).append('\n');
        }
        return text.toString();
    }

    public record Requested(UUID id) {}
}
