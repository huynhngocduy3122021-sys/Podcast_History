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
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.List;
import java.util.Objects;
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
    private final BigDecimal autoApproveConfidenceThreshold;

    public AiModerationService(AiModerationResultRepository results, PodcastRepository podcasts,
            GeminiModerationClient gemini, AdminSupportService support, ApplicationEventPublisher events,
            PodcastTranscriptRepository transcripts, PodcastReviewService podcastReviews,
            @org.springframework.beans.factory.annotation.Value("${gemini.auto-approve-confidence-threshold:0.90}")
            BigDecimal autoApproveConfidenceThreshold) {
        this.results = results;
        this.podcasts = podcasts;
        this.gemini = gemini;
        this.support = support;
        this.events = events;
        this.transcripts = transcripts;
        this.podcastReviews = podcastReviews;
        if (autoApproveConfidenceThreshold.compareTo(ModerationResponseValidator.ZERO) < 0
                || autoApproveConfidenceThreshold.compareTo(ModerationResponseValidator.ONE) > 0) {
            throw new IllegalArgumentException("gemini.auto-approve-confidence-threshold must be between 0.0 and 1.0.");
        }
        this.autoApproveConfidenceThreshold = autoApproveConfidenceThreshold;
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
    @Transactional
    public AiModerationItem enqueue(Podcast podcast) {
        Podcast lockedPodcast = podcasts.lockById(podcast.getPodcastId()).orElse(podcast);
        String sourceHash = hash(lockedPodcast);
        String mediaKey = lockedPodcast.getMediaUrl();
        PodcastTranscript transcript = transcripts
                .findByPodcast_PodcastIdAndMediaKey(lockedPodcast.getPodcastId(), mediaKey)
                .orElse(null);
        String transcriptHash = completedTranscriptHash(transcript);

        List<AiModerationResult> candidates = results
                .findAllByPodcast_PodcastIdAndSourceHashAndMediaKeyOrderByCreatedAtDesc(
                        lockedPodcast.getPodcastId(), sourceHash, mediaKey);
        for (AiModerationResult candidate : candidates) {
            if (!sameContentVersion(candidate, transcript, transcriptHash)) {
                if (isActive(candidate)) {
                    finish(candidate, "SKIPPED", "STALE", "REVIEW",
                            "Phiên bản moderation cũ không còn áp dụng cho transcript hiện tại.", null, null);
                }
                continue;
            }
            if (isActive(candidate)) return item(candidate, true);
            if ("COMPLETED".equalsIgnoreCase(candidate.getStatus())) return item(candidate, true);
            if ("FAILED".equalsIgnoreCase(candidate.getStatus())) {
                resetForRetry(candidate, lockedPodcast, transcript, transcriptHash, sourceHash, mediaKey);
                results.save(candidate);
                events.publishEvent(new Requested(candidate.getModerationResultId()));
                return item(candidate, true);
            }
        }

        AiModerationResult result = new AiModerationResult();
        result.setPodcast(lockedPodcast);
        result.setModelName(gemini.model());
        result.setOverallLabel("PENDING");
        result.setStatus("PENDING");
        result.setSourceHash(sourceHash);
        result.setMediaKey(mediaKey);
        result.setTranscript(transcript);
        result.setTranscriptHash(transcriptHash);
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
        Podcast podcast = podcasts.findByPodcastId(event.podcastId()).orElse(null);
        if (podcast == null) return;
        PodcastTranscript transcript = transcripts
                .findByPodcast_PodcastIdAndMediaKey(event.podcastId(), event.mediaKey()).orElse(null);
        String currentSourceHash = hash(podcast);
        String currentTranscriptHash = completedTranscriptHash(transcript);
        List<AiModerationResult> pending = results
                .findAllByPodcast_PodcastIdAndStatusAndMediaKeyOrderByCreatedAtDesc(
                        event.podcastId(), "PENDING", event.mediaKey());
        AiModerationResult winner = pending.stream()
                .filter(r -> Objects.equals(r.getSourceHash(), currentSourceHash)
                        && sameContentVersion(r, transcript, currentTranscriptHash))
                .findFirst().orElse(null);
        if (winner == null) return;
        for (AiModerationResult duplicate : pending) {
            if (duplicate.getModerationResultId().equals(winner.getModerationResultId())) continue;
            if (Objects.equals(duplicate.getSourceHash(), currentSourceHash)
                    && sameContentVersion(duplicate, transcript, currentTranscriptHash)) {
                finish(duplicate, "SKIPPED", "DUPLICATE", "REVIEW",
                        "Job moderation trùng phiên bản đã được bỏ qua.", null, null);
            }
        }
        process(winner.getModerationResultId());
    }

    private void process(UUID id) {
        AiModerationResult result = results.findById(id).orElse(null);
        if (result == null || !"PENDING".equals(result.getStatus())) return;
        Podcast podcast = podcasts.findByPodcastId(result.getPodcast().getPodcastId()).orElse(null);
        if (podcast == null) return;
        if (!Objects.equals(result.getSourceHash(), hash(podcast))
                || !Objects.equals(result.getMediaKey(), podcast.getMediaUrl())) {
            finish(result, "SKIPPED", "STALE", "REVIEW", "Podcast đã thay đổi sau khi gửi duyệt.", null, null);
            return;
        }
        PodcastTranscript transcript = transcripts
                .findByPodcast_PodcastIdAndMediaKey(podcast.getPodcastId(), podcast.getMediaUrl())
                .orElse(null);
        String transcriptHash = completedTranscriptHash(transcript);
        if (!sameContentVersion(result, transcript, transcriptHash)) {
            finish(result, "SKIPPED", "STALE", "REVIEW",
                    "Phiên bản moderation cũ không còn áp dụng cho transcript hiện tại.", null, null);
            return;
        }
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
            var validated = ModerationResponseValidator.validate(output);
            result.setConfidenceScore(validated.confidence());
            Podcast latestPodcast = podcasts.findByPodcastId(podcast.getPodcastId()).orElse(null);
            PodcastTranscript latestTranscript = latestPodcast == null ? null
                    : transcripts.findByPodcast_PodcastIdAndMediaKey(
                            latestPodcast.getPodcastId(), latestPodcast.getMediaUrl()).orElse(null);
            if (latestPodcast == null
                    || !Objects.equals(result.getSourceHash(), hash(latestPodcast))
                    || !Objects.equals(result.getMediaKey(), latestPodcast.getMediaUrl())
                    || !sameContentVersion(result, latestTranscript, completedTranscriptHash(latestTranscript))) {
                finish(result, "SKIPPED", "STALE", "REVIEW",
                        "Podcast hoặc transcript đã thay đổi trong lúc AI xử lý.", null, null);
                return;
            }
            finish(result, "COMPLETED", validated.label(), validated.recommendation(), validated.reason(), output, null);
        } catch (Exception exception) {
            if (exception instanceof InterruptedException) Thread.currentThread().interrupt();
            String message = exception.getMessage();
            String error = message == null ? exception.getClass().getSimpleName() : message;
            finish(result, "FAILED", "ERROR", "REVIEW", "AI không xử lý được; cần Admin duyệt thủ công.",
                    null, error.substring(0, Math.min(error.length(), 500)));
        }
        if (isAutoApproveEligible(result, autoApproveConfidenceThreshold)) {
            podcastReviews.autoApprove(result.getModerationResultId());
        }
    }

    static boolean isAutoApproveEligible(AiModerationResult result, BigDecimal threshold) {
        return "COMPLETED".equals(result.getStatus())
                && "SAFE".equals(result.getOverallLabel())
                && "APPROVE".equals(result.getRecommendation())
                && meetsAutoApproveConfidence(result, threshold);
    }

    private static boolean meetsAutoApproveConfidence(AiModerationResult result, BigDecimal threshold) {
        return result.getConfidenceScore() != null
                && result.getConfidenceScore().compareTo(threshold) >= 0;
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

    private void resetForRetry(AiModerationResult result, Podcast podcast, PodcastTranscript transcript,
            String transcriptHash, String sourceHash, String mediaKey) {
        result.setPodcast(podcast);
        result.setModelName(gemini.model());
        result.setOverallLabel("PENDING");
        result.setRecommendation(null);
        result.setConfidenceScore(null);
        result.setReason(null);
        result.setRawResult(null);
        result.setErrorMessage(null);
        result.setProcessedAt(null);
        result.setStatus("PENDING");
        result.setSourceHash(sourceHash);
        result.setMediaKey(mediaKey);
        result.setTranscript(transcript);
        result.setTranscriptHash(transcriptHash);
    }

    static boolean sameContentVersion(AiModerationResult result, PodcastTranscript transcript,
            String transcriptHash) {
        if (transcript == null) {
            return result.getTranscript() == null && !"COMPLETED".equalsIgnoreCase(result.getStatus());
        }
        if (result.getTranscript() == null
                || !Objects.equals(result.getTranscript().getTranscriptId(), transcript.getTranscriptId())) {
            return false;
        }
        if (transcriptHash == null) {
            return !"COMPLETED".equalsIgnoreCase(result.getStatus()) && result.getTranscriptHash() == null;
        }
        return Objects.equals(result.getTranscriptHash(), transcriptHash)
                || (isActive(result) && result.getTranscriptHash() == null);
    }

    private String completedTranscriptHash(PodcastTranscript transcript) {
        if (transcript == null || !"COMPLETED".equalsIgnoreCase(transcript.getStatus())
                || transcript.getFullText() == null || transcript.getFullText().isBlank()) return null;
        return hashText(transcript.getFullText());
    }

    private static boolean isActive(AiModerationResult result) {
        return "PENDING".equalsIgnoreCase(result.getStatus())
                || "PROCESSING".equalsIgnoreCase(result.getStatus());
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
