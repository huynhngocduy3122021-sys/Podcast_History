package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.prmteam7.podcasthistory.model.AiModerationResult;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.Podcast;
import com.prmteam7.podcasthistory.model.PodcastTranscript;
import com.prmteam7.podcasthistory.model.ProducerProfile;
import com.prmteam7.podcasthistory.repository.AiModerationResultRepository;
import com.prmteam7.podcasthistory.repository.PodcastRepository;
import com.prmteam7.podcasthistory.repository.PodcastTranscriptRepository;
import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationEventPublisher;
import tools.jackson.databind.ObjectMapper;

class AiModerationNotificationTest {
    @Test
    void unsafeAiResultNotifiesCreatorOnceWithoutRejectingPodcast() throws Exception {
        Fixture fixture = new Fixture();
        fixture.transcript.setStatus("COMPLETED");
        fixture.transcript.setFullText("Nội dung cần kiểm tra");
        when(fixture.gemini.configured()).thenReturn(true);
        when(fixture.gemini.analyze(any(), any(), any())).thenReturn(
                new GeminiModerationClient.ModerationResponse(new ObjectMapper().readTree("""
                        {"label":"UNSAFE","recommendation":"REJECT","confidence":0.95,
                         "reason":"Lời nói không an toàn","evidence":[]}
                        """), "test"));

        fixture.service.onRequested(new AiModerationService.Requested(fixture.job.getModerationResultId()));
        fixture.service.onRequested(new AiModerationService.Requested(fixture.job.getModerationResultId()));

        assertEquals("COMPLETED", fixture.job.getStatus());
        assertEquals("PENDING_REVIEW", fixture.podcast.getStatus());
        verify(fixture.support, times(1)).notify(eq(fixture.creator), eq("PODCAST_REVIEW"),
                contains("AI chưa thể duyệt"), contains("chờ Admin/Staff"));
        verify(fixture.reviews, never()).autoApprove(any());
    }

    @Test
    void transcriptFailureNotifiesCreatorAndDoesNotChangePodcastStatus() {
        Fixture fixture = new Fixture();
        fixture.transcript.setStatus("FAILED");

        fixture.service.onRequested(new AiModerationService.Requested(fixture.job.getModerationResultId()));

        assertEquals("FAILED", fixture.job.getStatus());
        assertEquals("PENDING_REVIEW", fixture.podcast.getStatus());
        verify(fixture.support).notify(eq(fixture.creator), eq("PODCAST_REVIEW"),
                contains("AI chưa thể duyệt"), contains("chờ Admin/Staff"));
    }

    @Test
    void staleJobDoesNotNotifyCreator() {
        Fixture fixture = new Fixture();
        fixture.podcast.setMediaUrl("new-media.mp3");

        fixture.service.onRequested(new AiModerationService.Requested(fixture.job.getModerationResultId()));

        assertEquals("SKIPPED", fixture.job.getStatus());
        verify(fixture.support, never()).notify(any(), any(), any(), any());
    }

    private static final class Fixture {
        private final AiModerationResultRepository results = mock(AiModerationResultRepository.class);
        private final PodcastRepository podcasts = mock(PodcastRepository.class);
        private final PodcastTranscriptRepository transcripts = mock(PodcastTranscriptRepository.class);
        private final GeminiModerationClient gemini = mock(GeminiModerationClient.class);
        private final AdminSupportService support = mock(AdminSupportService.class);
        private final PodcastReviewService reviews = mock(PodcastReviewService.class);
        private final AppUser creator = new AppUser();
        private final Podcast podcast = new Podcast();
        private final PodcastTranscript transcript = new PodcastTranscript();
        private final AiModerationResult job = new AiModerationResult();
        private final AiModerationService service;

        private Fixture() {
            UUID podcastId = UUID.randomUUID();
            UUID jobId = UUID.randomUUID();
            podcast.setPodcastId(podcastId);
            podcast.setTitle("Podcast");
            podcast.setMediaUrl("media.mp3");
            podcast.setStatus("PENDING_REVIEW");
            ProducerProfile profile = new ProducerProfile();
            profile.setUser(creator);
            podcast.setProducerProfile(profile);
            transcript.setPodcast(podcast);
            transcript.setMediaKey(podcast.getMediaUrl());
            job.setModerationResultId(jobId);
            job.setPodcast(podcast);
            job.setTranscript(transcript);
            job.setSourceHash(AiModerationService.hash(podcast));
            job.setMediaKey(podcast.getMediaUrl());
            when(results.findById(jobId)).thenReturn(Optional.of(job));
            when(results.claim(jobId)).thenReturn(1);
            when(results.save(any(AiModerationResult.class))).thenAnswer(invocation -> invocation.getArgument(0));
            when(podcasts.findByPodcastId(podcastId)).thenReturn(Optional.of(podcast));
            when(transcripts.findByPodcast_PodcastIdAndMediaKey(podcastId, "media.mp3"))
                    .thenReturn(Optional.of(transcript));
            service = new AiModerationService(results, podcasts, gemini, support,
                    mock(ApplicationEventPublisher.class), transcripts, reviews, new BigDecimal("0.90"));
        }
    }
}
