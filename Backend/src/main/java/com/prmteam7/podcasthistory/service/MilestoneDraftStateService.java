package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.model.MilestoneDraft;
import com.prmteam7.podcasthistory.repository.MilestoneDraftRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MilestoneDraftStateService {
    private final MilestoneDraftRepository drafts;

    public MilestoneDraftStateService(MilestoneDraftRepository drafts) { this.drafts = drafts; }

    @Transactional
    public ReviewJob claim(UUID id) {
        UUID token = UUID.randomUUID();
        Instant now = Instant.now();
        if (drafts.claim(id, token, now, now.minus(45, ChronoUnit.MINUTES)) != 1) return null;
        MilestoneDraft draft = drafts.findById(id).orElseThrow();
        return new ReviewJob(id, token, draft.getObjectKey());
    }

    @Transactional
    public boolean finish(ReviewJob job, String status, String label, String recommendation,
            BigDecimal confidence, String reason, String error) {
        MilestoneDraft draft = drafts.lockById(job.id()).orElse(null);
        if (draft == null || !"PROCESSING".equals(draft.getStatus())
                || !job.token().equals(draft.getAttemptToken())) return false;
        draft.setStatus(status);
        draft.setAiLabel(label);
        draft.setAiRecommendation(recommendation);
        draft.setAiConfidence(confidence);
        draft.setAiReason(reason);
        draft.setErrorMessage(error);
        draft.setReviewedAt(Instant.now());
        draft.setAttemptToken(null);
        drafts.save(draft);
        return true;
    }

    public record ReviewJob(UUID id, UUID token, String objectKey) {}
}
