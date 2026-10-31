package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.repository.MilestoneDraftRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class MilestoneDraftAiReviewJob {
    private static final Logger log = LoggerFactory.getLogger(MilestoneDraftAiReviewJob.class);
    private final MilestoneDraftRepository drafts;
    private final MilestoneDraftStateService state;
    private final WhisperTranscriptionClient whisper;
    private final GeminiModerationClient gemini;
    private final BigDecimal threshold;

    public MilestoneDraftAiReviewJob(MilestoneDraftRepository drafts, MilestoneDraftStateService state,
            WhisperTranscriptionClient whisper, GeminiModerationClient gemini,
            @Value("${gemini.auto-approve-confidence-threshold:0.90}") BigDecimal threshold) {
        this.drafts = drafts;
        this.state = state;
        this.whisper = whisper;
        this.gemini = gemini;
        if (threshold.compareTo(BigDecimal.ZERO) < 0 || threshold.compareTo(BigDecimal.ONE) > 0)
            throw new IllegalArgumentException("Ngưỡng tin cậy AI phải trong khoảng 0..1.");
        this.threshold = threshold;
    }

    @Scheduled(fixedDelay = 30_000)
    public void run() {
        for (UUID id : drafts.findReviewCandidates(Instant.now().minus(45, ChronoUnit.MINUTES),
                PageRequest.of(0, 20))) {
            try { review(id); }
            catch (RuntimeException exception) { log.error("Không thể kiểm duyệt bản nháp {}", id, exception); }
        }
    }

    void review(UUID id) {
        var job = state.claim(id);
        if (job == null) return;
        try {
            if (!gemini.configured()) throw new IllegalStateException("GEMINI_API_KEY chưa được cấu hình.");
            var transcript = whisper.transcribe(job.objectKey());
            String speech = transcript.path("fullText").asText();
            if (speech == null || speech.isBlank()) {
                state.finish(job, "REVIEW_REQUIRED", "UNCERTAIN", "REVIEW", null,
                        "Không có lời nói đủ rõ để AI kiểm duyệt; CC cần nộp bản khác.", null);
                return;
            }
            var result = gemini.analyze("", "", speech);
            var validated = ModerationResponseValidator.validate(result.output());
            boolean approved = "SAFE".equals(validated.label())
                    && "APPROVE".equals(validated.recommendation())
                    && validated.confidence().compareTo(threshold) >= 0;
            String status = approved ? "APPROVED"
                    : "UNSAFE".equals(validated.label()) ? "REJECTED" : "REVIEW_REQUIRED";
            state.finish(job, status, validated.label(), validated.recommendation(),
                    validated.confidence(), validated.reason(), null);
        } catch (Exception exception) {
            if (exception instanceof InterruptedException) Thread.currentThread().interrupt();
            String detail = exception.getMessage() == null
                    ? exception.getClass().getSimpleName() : exception.getMessage();
            state.finish(job, "FAILED", "ERROR", "REVIEW", null,
                    "AI không kiểm duyệt được bản nháp.", detail.substring(0, Math.min(detail.length(), 500)));
        }
    }
}
