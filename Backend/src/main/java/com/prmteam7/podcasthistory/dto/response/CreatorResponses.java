package com.prmteam7.podcasthistory.dto.response;

import java.time.Instant;
import java.util.UUID;
import com.prmteam7.podcasthistory.enums.PodcastVisibility;

public final class CreatorResponses {

    private CreatorResponses() {
    }

    public record SeriesItem(
            UUID seriesId,
            UUID categoryId,
            String categoryName,
            String title,
            String slug,
            String description,
            String coverUrl,
            String status,
            Instant publishedAt,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record PodcastItem(
            UUID podcastId,
            UUID seriesId,
            String seriesTitle,
            UUID categoryId,
            String categoryName,
            String title,
            String description,
            String mediaKey,
            String mediaType,
            String videoUrl,
            Instant videoUrlExpiresAt,
            String thumbnailUrl,
            Integer durationSeconds,
            Integer episodeNumber,
            Boolean exclusive,
            PodcastVisibility visibility,
            String status,
            Instant publishedAt,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record PodcastVideoItem(
            UUID podcastId,
            String podcastTitle,
            String status,
            MediaUploadResponse media) {
    }

    public record PodcastReviewItem(
            UUID podcastId,
            UUID creatorProfileId,
            String creatorChannelName,
            UUID categoryId,
            String categoryName,
            UUID seriesId,
            String seriesTitle,
            String title,
            String description,
            String mediaKey,
            String mediaType,
            String thumbnailUrl,
            Integer durationSeconds,
            Boolean exclusive,
            PodcastVisibility visibility,
            String status,
            Instant submittedAt) {
    }

    public record PodcastReviewResult(UUID podcastId, String status, String note, Instant reviewedAt) {
    }
}
