package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.prmteam7.podcasthistory.dto.request.CreatorRequests.PodcastWrite;
import com.prmteam7.podcasthistory.dto.response.MediaUploadResponse;
import com.prmteam7.podcasthistory.enums.PodcastVisibility;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.Category;
import com.prmteam7.podcasthistory.model.Podcast;
import com.prmteam7.podcasthistory.model.ProducerProfile;
import com.prmteam7.podcasthistory.model.Role;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.CategoryRepository;
import com.prmteam7.podcasthistory.repository.PodcastRepository;
import com.prmteam7.podcasthistory.repository.ProducerProfileRepository;
import com.prmteam7.podcasthistory.repository.SeriesRepository;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

class CreatorPodcastEditReviewTest {
    @Test
    void editingPublishedMetadataKeepsPublicationAndDoesNotEnqueueAi() {
        Fixture fixture = new Fixture();
        fixture.podcast.setStatus("APPROVED");
        Instant publishedAt = Instant.now();
        fixture.podcast.setPublishedAt(publishedAt);

        var response = fixture.service.updatePodcast(fixture.userId, fixture.podcastId, fixture.write());

        assertEquals("APPROVED", response.status());
        assertEquals(publishedAt, response.publishedAt());
        assertEquals("Tiêu đề mới", response.title());
        verify(fixture.aiModeration, never()).enqueue(any());
        verify(fixture.transcriptService, never()).enqueue(any());
    }

    @Test
    void submittingAlreadyApprovedPodcastCannotStartReviewWithoutNewMedia() {
        Fixture fixture = new Fixture();
        fixture.podcast.setStatus("APPROVED");

        assertThrows(ResourceConflictException.class,
                () -> fixture.service.submitPodcast(fixture.userId, fixture.podcastId));
        assertEquals("APPROVED", fixture.podcast.getStatus());
        verify(fixture.aiModeration, never()).enqueue(any());
    }

    @Test
    void replacingMediaMovesApprovedPodcastToDraftAndStartsNewTranscript() {
        Fixture fixture = new Fixture();
        fixture.podcast.setStatus("APPROVED");
        fixture.podcast.setPublishedAt(Instant.now());
        MultipartFile file = mock(MultipartFile.class);
        when(fixture.mediaUpload.uploadPodcastVideo(file, fixture.userId, fixture.podcastId))
                .thenReturn(new MediaUploadResponse("video/new.mp4", "test", null, "video/mp4", 100L));

        TransactionSynchronizationManager.initSynchronization();
        try {
            fixture.service.uploadPodcastVideo(fixture.userId, fixture.podcastId, file);
        } finally {
            TransactionSynchronizationManager.clearSynchronization();
        }

        assertEquals("DRAFT", fixture.podcast.getStatus());
        assertEquals(null, fixture.podcast.getPublishedAt());
        assertEquals("video/new.mp4", fixture.podcast.getMediaUrl());
        verify(fixture.transcriptService).enqueue(fixture.podcast);
        verify(fixture.aiModeration, never()).enqueue(any());

        fixture.service.submitPodcast(fixture.userId, fixture.podcastId);
        assertEquals("PENDING_REVIEW", fixture.podcast.getStatus());
        verify(fixture.aiModeration).enqueue(fixture.podcast);
    }

    private static final class Fixture {
        final UUID userId = UUID.randomUUID();
        final UUID profileId = UUID.randomUUID();
        final UUID podcastId = UUID.randomUUID();
        final UUID categoryId = UUID.randomUUID();
        final AppUserRepository users = mock(AppUserRepository.class);
        final ProducerProfileRepository profiles = mock(ProducerProfileRepository.class);
        final CategoryRepository categories = mock(CategoryRepository.class);
        final SeriesRepository series = mock(SeriesRepository.class);
        final PodcastRepository podcasts = mock(PodcastRepository.class);
        final AiModerationService aiModeration = mock(AiModerationService.class);
        final PodcastTranscriptService transcriptService = mock(PodcastTranscriptService.class);
        final MediaUploadService mediaUpload = mock(MediaUploadService.class);
        final CreatorFlowService service = new CreatorFlowService(users, profiles, categories, series,
                podcasts, mediaUpload, mock(R2PlaybackUrlService.class),
                mock(CreatorSystemPlanService.class), aiModeration, transcriptService);
        final Podcast podcast = new Podcast();

        Fixture() {
            Role role = new Role();
            role.setRoleCode("CREATOR");
            AppUser user = new AppUser();
            user.setIsActive(true);
            user.setRole(role);
            ProducerProfile profile = new ProducerProfile();
            profile.setProducerProfileId(profileId);
            profile.setVerificationStatus("APPROVED");
            Category category = new Category();
            category.setCategoryId(categoryId);
            category.setName("Lịch sử");
            category.setIsActive(true);
            podcast.setPodcastId(podcastId);
            podcast.setCategory(category);
            podcast.setMediaUrl("video/old.mp4");
            podcast.setMediaType("video/mp4");
            when(users.findById(userId)).thenReturn(Optional.of(user));
            when(profiles.findByUser_UserId(userId)).thenReturn(Optional.of(profile));
            when(podcasts.findByPodcastIdAndProducerProfile_ProducerProfileId(podcastId, profileId))
                    .thenReturn(Optional.of(podcast));
            when(categories.findById(categoryId)).thenReturn(Optional.of(category));
            when(podcasts.save(any(Podcast.class))).thenAnswer(call -> call.getArgument(0));
        }

        PodcastWrite write() {
            return new PodcastWrite(categoryId, "Tiêu đề mới", "Mô tả mới", "cover.jpg", 120,
                    1, PodcastVisibility.PUBLIC, false);
        }
    }
}
