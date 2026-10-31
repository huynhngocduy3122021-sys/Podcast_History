package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.prmteam7.podcasthistory.model.MilestoneDraft;
import com.prmteam7.podcasthistory.repository.MilestoneDraftRepository;
import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import tools.jackson.databind.ObjectMapper;

@ExtendWith(MockitoExtension.class)
class MilestoneDraftAiReviewJobTest {
    @Mock MilestoneDraftRepository drafts;
    @Mock MilestoneDraftStateService state;
    @Mock WhisperTranscriptionClient whisper;
    @Mock GeminiModerationClient gemini;
    private final ObjectMapper mapper = new ObjectMapper();

    @Test
    void safeSpeechAboveThresholdOpensDelivery() throws Exception {
        UUID id = UUID.randomUUID();
        var job = new MilestoneDraftStateService.ReviewJob(id, UUID.randomUUID(), "private/media");
        when(state.claim(id)).thenReturn(job);
        when(whisper.transcribe("private/media")).thenReturn(mapper.readTree("{\"fullText\":\"Xin chào\"}"));
        when(gemini.configured()).thenReturn(true);
        when(gemini.analyze("", "", "Xin chào"))
                .thenReturn(new GeminiModerationClient.ModerationResponse(mapper.readTree(
                        "{\"label\":\"SAFE\",\"recommendation\":\"APPROVE\",\"confidence\":0.95,\"reason\":\"An toàn\",\"evidence\":[]}"), "test"));

        new MilestoneDraftAiReviewJob(drafts, state, whisper, gemini, new BigDecimal("0.90")).review(id);

        verify(state).finish(eq(job), eq("APPROVED"), eq("SAFE"), eq("APPROVE"),
                eq(new BigDecimal("0.95")), eq("An toàn"), isNull());
    }

    @Test
    void noSpeechFailsClosedBeforeGemini() throws Exception {
        UUID id = UUID.randomUUID();
        var job = new MilestoneDraftStateService.ReviewJob(id, UUID.randomUUID(), "private/media");
        when(state.claim(id)).thenReturn(job);
        when(gemini.configured()).thenReturn(true);
        when(whisper.transcribe("private/media")).thenReturn(mapper.readTree("{\"fullText\":\"\"}"));

        new MilestoneDraftAiReviewJob(drafts, state, whisper, gemini, new BigDecimal("0.90")).review(id);

        verify(state).finish(eq(job), eq("REVIEW_REQUIRED"), eq("UNCERTAIN"), eq("REVIEW"),
                isNull(), contains("Không có lời nói"), isNull());
        verify(gemini, never()).analyze(any(), any(), any());
    }

    @Test
    void safeSpeechBelowConfidenceThresholdCannotBeDelivered() throws Exception {
        UUID id = UUID.randomUUID();
        var job = new MilestoneDraftStateService.ReviewJob(id, UUID.randomUUID(), "private/media");
        when(state.claim(id)).thenReturn(job);
        when(gemini.configured()).thenReturn(true);
        when(whisper.transcribe("private/media")).thenReturn(mapper.readTree("{\"fullText\":\"Xin chào\"}"));
        when(gemini.analyze(any(), any(), any())).thenReturn(new GeminiModerationClient.ModerationResponse(
                mapper.readTree("{\"label\":\"SAFE\",\"recommendation\":\"APPROVE\",\"confidence\":0.60,\"reason\":\"Chưa chắc chắn\",\"evidence\":[]}"), "test"));

        new MilestoneDraftAiReviewJob(drafts, state, whisper, gemini, new BigDecimal("0.90")).review(id);

        verify(state).finish(eq(job), eq("REVIEW_REQUIRED"), eq("SAFE"), eq("APPROVE"),
                argThat(value -> value != null && value.compareTo(new BigDecimal("0.60")) == 0), any(), isNull());
    }

    @Test
    void unsafeSpeechIsRejected() throws Exception {
        UUID id = UUID.randomUUID();
        var job = new MilestoneDraftStateService.ReviewJob(id, UUID.randomUUID(), "private/media");
        when(state.claim(id)).thenReturn(job);
        when(gemini.configured()).thenReturn(true);
        when(whisper.transcribe("private/media")).thenReturn(mapper.readTree("{\"fullText\":\"Nội dung nguy hiểm\"}"));
        when(gemini.analyze(any(), any(), any())).thenReturn(new GeminiModerationClient.ModerationResponse(
                mapper.readTree("{\"label\":\"UNSAFE\",\"recommendation\":\"REJECT\",\"confidence\":0.99,\"reason\":\"Không an toàn\",\"evidence\":[]}"), "test"));

        new MilestoneDraftAiReviewJob(drafts, state, whisper, gemini, new BigDecimal("0.90")).review(id);

        verify(state).finish(eq(job), eq("REJECTED"), eq("UNSAFE"), eq("REJECT"),
                eq(new BigDecimal("0.99")), any(), isNull());
    }

    @Test
    void oldWorkerCannotOverwriteResultAfterAttemptTokenChanges() {
        UUID id = UUID.randomUUID();
        UUID oldToken = UUID.randomUUID();
        MilestoneDraft draft = new MilestoneDraft();
        draft.setId(id);
        draft.setStatus("PROCESSING");
        draft.setAttemptToken(UUID.randomUUID());
        when(drafts.lockById(id)).thenReturn(Optional.of(draft));
        MilestoneDraftStateService states = new MilestoneDraftStateService(drafts);

        boolean updated = states.finish(new MilestoneDraftStateService.ReviewJob(id, oldToken,
                "private/media"), "APPROVED", "SAFE", "APPROVE",
                new BigDecimal("0.99"), "An toàn", null);

        assertFalse(updated);
        assertEquals("PROCESSING", draft.getStatus());
        verify(drafts, never()).save(any());
    }
}
