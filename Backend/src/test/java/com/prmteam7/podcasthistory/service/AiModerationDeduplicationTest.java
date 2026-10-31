package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.prmteam7.podcasthistory.model.AiModerationResult;
import com.prmteam7.podcasthistory.model.Podcast;
import com.prmteam7.podcasthistory.model.PodcastTranscript;
import com.prmteam7.podcasthistory.repository.AiModerationResultRepository;
import com.prmteam7.podcasthistory.repository.PodcastRepository;
import com.prmteam7.podcasthistory.repository.PodcastTranscriptRepository;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationEventPublisher;

class AiModerationDeduplicationTest {
    private static final BigDecimal THRESHOLD = new BigDecimal("0.90");

    @Test
    void repeatedEnqueueReusesPendingProcessingAndCompletedVersion() {
        Fixture fixture = new Fixture();
        AiModerationService service = fixture.service();

        service.enqueue(fixture.podcast);
        service.enqueue(fixture.podcast);
        assertEquals(1, fixture.saved.size());
        verify(fixture.events, times(1)).publishEvent(any(AiModerationService.Requested.class));

        AiModerationResult job = fixture.saved.get(0);
        job.setStatus("PROCESSING");
        service.enqueue(fixture.podcast);
        assertEquals(1, fixture.saved.size());

        job.setStatus("COMPLETED");
        job.setTranscriptHash(AiModerationService.hashText(fixture.transcript.getFullText()));
        service.enqueue(fixture.podcast);
        assertEquals(1, fixture.saved.size());
    }

    @Test
    void failedVersionIsReusedForRetryInsteadOfCreatingUnlimitedRows() {
        Fixture fixture = new Fixture();
        AiModerationService service = fixture.service();

        service.enqueue(fixture.podcast);
        AiModerationResult job = fixture.saved.get(0);
        job.setStatus("FAILED");
        service.enqueue(fixture.podcast);

        assertEquals(1, fixture.saved.size());
        assertEquals("PENDING", job.getStatus());
        verify(fixture.events, times(2)).publishEvent(any(AiModerationService.Requested.class));
    }

    @Test
    void changedTranscriptHashDoesNotReuseCompletedResult() {
        Fixture fixture = new Fixture();
        AiModerationService service = fixture.service();

        service.enqueue(fixture.podcast);
        AiModerationResult old = fixture.saved.get(0);
        old.setStatus("COMPLETED");
        old.setTranscriptHash(AiModerationService.hashText(fixture.transcript.getFullText()));
        fixture.transcript.setFullText("Nội dung transcript phiên bản mới");
        service.enqueue(fixture.podcast);

        assertEquals(2, fixture.saved.size());
        assertFalse(fixture.saved.get(0) == fixture.saved.get(1));
    }

    @Test
    void versionGuardAllowsOnlyMatchingTranscriptForCompletedResult() {
        PodcastTranscript transcript = new PodcastTranscript();
        transcript.setStatus("COMPLETED");
        transcript.setFullText("Nội dung");
        AiModerationResult result = new AiModerationResult();
        result.setTranscript(transcript);
        result.setStatus("COMPLETED");
        result.setTranscriptHash(AiModerationService.hashText("Nội dung"));

        assertTrue(AiModerationService.sameContentVersion(
                result, transcript, AiModerationService.hashText("Nội dung")));
        assertFalse(AiModerationService.sameContentVersion(
                result, transcript, AiModerationService.hashText("Nội dung mới")));
    }

    private static final class Fixture {
        private final PodcastRepository podcasts = mock(PodcastRepository.class);
        private final AiModerationResultRepository results = mock(AiModerationResultRepository.class);
        private final PodcastTranscriptRepository transcripts = mock(PodcastTranscriptRepository.class);
        private final GeminiModerationClient gemini = mock(GeminiModerationClient.class);
        private final AdminSupportService support = mock(AdminSupportService.class);
        private final ApplicationEventPublisher events = mock(ApplicationEventPublisher.class);
        private final PodcastReviewService reviews = mock(PodcastReviewService.class);
        private final List<AiModerationResult> saved = new ArrayList<>();
        private final Podcast podcast = new Podcast();
        private final PodcastTranscript transcript = new PodcastTranscript();

        private Fixture() {
            UUID podcastId = UUID.randomUUID();
            podcast.setPodcastId(podcastId);
            podcast.setTitle("Podcast");
            podcast.setDescription("Mô tả");
            podcast.setMediaUrl("creator/podcast/audio.mp3");
            podcast.setMediaType("audio/mpeg");
            transcript.setPodcast(podcast);
            transcript.setMediaKey(podcast.getMediaUrl());
            transcript.setStatus("COMPLETED");
            transcript.setFullText("Nội dung transcript");
            when(podcasts.lockById(podcastId)).thenReturn(Optional.of(podcast));
            when(transcripts.findByPodcast_PodcastIdAndMediaKey(podcastId, podcast.getMediaUrl()))
                    .thenReturn(Optional.of(transcript));
            when(results.findAllByPodcast_PodcastIdAndSourceHashAndMediaKeyOrderByCreatedAtDesc(
                    any(), any(), any())).thenAnswer(invocation -> List.copyOf(saved));
            when(results.save(any(AiModerationResult.class))).thenAnswer(invocation -> {
                AiModerationResult value = invocation.getArgument(0);
                if (!saved.contains(value)) saved.add(value);
                return value;
            });
            when(gemini.model()).thenReturn("test-gemini");
        }

        private AiModerationService service() {
            return new AiModerationService(results, podcasts, gemini, support, events,
                    transcripts, reviews, THRESHOLD);
        }
    }
}
