package com.prmteam7.podcasthistory.dto.response;

import com.prmteam7.podcasthistory.dto.response.CreatorResponses.PodcastItem;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** Data needed by the Content Creator Studio home screen. */
public record CreatorDashboardResponse(
        Profile profile,
        Metrics metrics,
        List<GrowthPoint> growth,
        List<PodcastItem> recentPodcasts,
        List<SeriesRequestResponse> incomingRequests) {

    public record Profile(
            UUID creatorProfileId,
            UUID userId,
            String username,
            String displayName,
            String channelName,
            String description,
            String avatarUrl,
            String websiteUrl,
            String verificationStatus,
            boolean verified) {
    }

    public record Metrics(
            long trackCount,
            long followerCount,
            long totalListens,
            long monthlyListens,
            BigDecimal monthlyRevenue,
            BigDecimal availableBalance,
            BigDecimal pendingRelease,
            String currency) {
    }

    public record GrowthPoint(
            String label,
            Instant from,
            Instant to,
            long listens) {
    }
}
