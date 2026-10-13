package com.prmteam7.podcasthistory.service;

import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.prmteam7.podcasthistory.dto.response.CreatorResponses.PodcastReviewItem;
import com.prmteam7.podcasthistory.dto.response.CreatorResponses.PodcastReviewResult;
import com.prmteam7.podcasthistory.exception.InvalidFlowRequestException;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.exception.ResourceForbiddenException;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.ModerationReview;
import com.prmteam7.podcasthistory.model.Podcast;
import com.prmteam7.podcasthistory.model.Series;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.ModerationReviewRepository;
import com.prmteam7.podcasthistory.repository.PodcastRepository;

@Service
public class PodcastReviewService {

    private final AppUserRepository appUserRepository;
    private final PodcastRepository podcastRepository;
    private final ModerationReviewRepository moderationReviewRepository;

    public PodcastReviewService(
            AppUserRepository appUserRepository,
            PodcastRepository podcastRepository,
            ModerationReviewRepository moderationReviewRepository) {
        this.appUserRepository = appUserRepository;
        this.podcastRepository = podcastRepository;
        this.moderationReviewRepository = moderationReviewRepository;
    }

    @Transactional(readOnly = true)
    public List<PodcastReviewItem> listPodcasts(String status) {
        if (status == null || status.isBlank()) {
            return podcastRepository.findAllByOrderByCreatedAtDesc()
                    .stream().map(this::toReviewItem).toList();
        }
        String normalized = status.trim().toUpperCase(Locale.ROOT);
        if (!List.of("DRAFT", "PENDING_REVIEW", "APPROVED", "REJECTED", "PUBLISHED", "DELETED")
                .contains(normalized)) {
            throw new InvalidFlowRequestException("Trạng thái podcast không hợp lệ.");
        }
        return podcastRepository.findAllByStatusIgnoreCaseOrderByCreatedAtDesc(normalized)
                .stream().map(this::toReviewItem).toList();
    }

    @Transactional(readOnly = true)
    public List<PodcastReviewItem> pendingReview() {
        return podcastRepository.findAllByStatusIgnoreCaseOrderByUpdatedAtAsc("PENDING_REVIEW")
                .stream().map(this::toReviewItem).toList();
    }

    @Transactional
    public PodcastReviewResult approve(UUID reviewerId, UUID podcastId, String note) {
        return review(reviewerId, podcastId, "APPROVED", note);
    }

    @Transactional
    public PodcastReviewResult reject(UUID reviewerId, UUID podcastId, String note) {
        if (note == null || note.isBlank()) {
            throw new InvalidFlowRequestException("Vui lòng nhập lý do từ chối podcast.");
        }
        return review(reviewerId, podcastId, "REJECTED", note);
    }

    private PodcastReviewResult review(UUID reviewerId, UUID podcastId, String decision, String note) {
        AppUser reviewer = appUserRepository.findById(reviewerId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản Admin."));
        if (reviewer.getIsActive() == null || !reviewer.getIsActive()
                || reviewer.getRole() == null
                || !"ADMIN".equalsIgnoreCase(reviewer.getRole().getRoleCode())) {
            throw new ResourceForbiddenException("Chỉ Admin đang hoạt động mới được duyệt podcast.");
        }

        Podcast podcast = podcastRepository.findById(podcastId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy podcast."));
        if (!"PENDING_REVIEW".equalsIgnoreCase(podcast.getStatus())) {
            throw new ResourceConflictException("Podcast không ở trạng thái chờ duyệt.");
        }

        Instant reviewedAt = Instant.now();
        podcast.setStatus(decision);
        podcast.setPublishedAt("APPROVED".equals(decision) ? reviewedAt : null);
        podcastRepository.save(podcast);

        ModerationReview review = new ModerationReview();
        review.setPodcast(podcast);
        review.setReviewerUser(reviewer);
        review.setDecision(decision);
        review.setNote(note == null || note.isBlank() ? null : note.trim());
        review.setReviewedAt(reviewedAt);
        moderationReviewRepository.save(review);

        return new PodcastReviewResult(podcastId, decision, review.getNote(), reviewedAt);
    }

    private PodcastReviewItem toReviewItem(Podcast podcast) {
        Series series = podcast.getSeries();
        return new PodcastReviewItem(
                podcast.getPodcastId(),
                podcast.getProducerProfile().getProducerProfileId(),
                podcast.getProducerProfile().getChannelName(),
                podcast.getCategory().getCategoryId(),
                podcast.getCategory().getName(),
                series == null ? null : series.getSeriesId(),
                series == null ? null : series.getTitle(),
                podcast.getTitle(),
                podcast.getDescription(),
                podcast.getMediaUrl(),
                podcast.getMediaType(),
                podcast.getThumbnailUrl(),
                podcast.getDurationSeconds(),
                podcast.getIsExclusive(),
                com.prmteam7.podcasthistory.enums.PodcastVisibility.fromExclusive(podcast.getIsExclusive()),
                podcast.getStatus(),
                podcast.getUpdatedAt());
    }
}
