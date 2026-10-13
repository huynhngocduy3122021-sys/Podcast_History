package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;
import com.prmteam7.podcasthistory.enums.PodcastVisibility;

public final class ListenerResponses {

    private ListenerResponses() {
    }

    public record CategoryItem(UUID categoryId, String name, String slug, String description) {
    }

    public record CreatorItem(
            UUID creatorProfileId,
            String channelName,
            String description,
            String avatarUrl,
            String websiteUrl) {
    }

    public record PodcastItem(
            UUID podcastId,
            String title,
            String description,
            String mediaType,
            String thumbnailUrl,
            Integer durationSeconds,
            Integer episodeNumber,
            Boolean exclusive,
            PodcastVisibility visibility,
            Instant publishedAt,
            UUID seriesId,
            String seriesTitle,
            UUID categoryId,
            String categoryName,
            UUID creatorProfileId,
            String creatorChannelName) {
    }

    public record PlaybackItem(
            UUID podcastId,
            String playbackUrl,
            Instant expiresAt,
            Integer durationSeconds,
            Integer resumeFromSeconds) {
    }

    public record ListeningHistoryItem(
            UUID listeningHistoryId,
            UUID podcastId,
            String podcastTitle,
            String thumbnailUrl,
            Integer progressSeconds,
            Boolean completed,
            Instant lastListenedAt) {
    }

    public record LikeSummary(UUID podcastId, long likeCount, boolean likedByMe) {
    }

    public record CommentItem(
            UUID commentId,
            UUID podcastId,
            UUID userId,
            String username,
            String displayName,
            String avatarUrl,
            String content,
            String status,
            Instant createdAt,
            Instant updatedAt) {
    }

    public record ReportItem(
            UUID reportId,
            String targetType,
            UUID targetId,
            String reasonCode,
            String description,
            String status,
            Instant createdAt,
            Instant resolvedAt) {
    }

    public record FollowItem(
            UUID followId,
            UUID creatorProfileId,
            String channelName,
            String description,
            String avatarUrl,
            Instant followedAt) {
    }

    public record SavedPodcastItem(
            UUID savedPodcastId,
            UUID podcastId,
            String title,
            String thumbnailUrl,
            String creatorChannelName,
            Instant savedAt) {
    }

    public record MembershipPlanItem(
            UUID membershipPlanId,
            UUID creatorProfileId,
            String creatorChannelName,
            String name,
            String description,
            BigDecimal price,
            String currency,
            Integer durationDays) {
    }

    public record SubscriptionItem(
            UUID subscriptionId,
            UUID membershipPlanId,
            String planName,
            UUID creatorProfileId,
            String creatorChannelName,
            Instant startAt,
            Instant endAt,
            String status,
            Boolean autoRenew,
            UUID paymentId,
            String paymentStatus) {
    }

    public record MembershipCheckoutItem(
            UUID subscriptionId,
            UUID paymentId,
            BigDecimal amount,
            String currency,
            String subscriptionStatus,
            String paymentStatus,
            String message) {
    }

    public record SeriesRequestItem(
            UUID seriesRequestId,
            UUID creatorProfileId,
            String creatorChannelName,
            String requestedTitle,
            String description,
            BigDecimal requestFee,
            String currency,
            String status,
            Instant createdAt,
            Instant respondedAt,
            String creatorResponse,
            String creatorResponseStatus) {
    }
}
