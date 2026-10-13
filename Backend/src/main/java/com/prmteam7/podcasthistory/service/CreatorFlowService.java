package com.prmteam7.podcasthistory.service;

import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.prmteam7.podcasthistory.dto.request.CreatorRequests.PodcastWrite;
import com.prmteam7.podcasthistory.dto.request.CreatorRequests.SeriesWrite;
import com.prmteam7.podcasthistory.dto.response.CreatorResponses.PodcastItem;
import com.prmteam7.podcasthistory.dto.response.CreatorResponses.PodcastVideoItem;
import com.prmteam7.podcasthistory.dto.response.CreatorResponses.SeriesItem;
import com.prmteam7.podcasthistory.dto.response.MediaUploadResponse;
import com.prmteam7.podcasthistory.exception.InvalidFlowRequestException;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.exception.ResourceForbiddenException;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.Category;
import com.prmteam7.podcasthistory.model.Podcast;
import com.prmteam7.podcasthistory.model.ProducerProfile;
import com.prmteam7.podcasthistory.model.Series;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.CategoryRepository;
import com.prmteam7.podcasthistory.repository.PodcastRepository;
import com.prmteam7.podcasthistory.repository.ProducerProfileRepository;
import com.prmteam7.podcasthistory.repository.SeriesRepository;

@Service
public class CreatorFlowService {

    private final AppUserRepository appUserRepository;
    private final ProducerProfileRepository producerProfileRepository;
    private final CategoryRepository categoryRepository;
    private final SeriesRepository seriesRepository;
    private final PodcastRepository podcastRepository;
    private final MediaUploadService mediaUploadService;
    private final R2PlaybackUrlService playbackUrlService;

    public CreatorFlowService(
            AppUserRepository appUserRepository,
            ProducerProfileRepository producerProfileRepository,
            CategoryRepository categoryRepository,
            SeriesRepository seriesRepository,
            PodcastRepository podcastRepository,
            MediaUploadService mediaUploadService,
            R2PlaybackUrlService playbackUrlService) {
        this.appUserRepository = appUserRepository;
        this.producerProfileRepository = producerProfileRepository;
        this.categoryRepository = categoryRepository;
        this.seriesRepository = seriesRepository;
        this.podcastRepository = podcastRepository;
        this.mediaUploadService = mediaUploadService;
        this.playbackUrlService = playbackUrlService;
    }

    @Transactional(readOnly = true)
    public List<SeriesItem> listSeries(UUID userId) {
        ProducerProfile profile = approvedCreator(userId);
        return seriesRepository.findAllByProducerProfile_ProducerProfileIdOrderByCreatedAtDesc(
                        profile.getProducerProfileId())
                .stream().map(this::toSeriesItem).toList();
    }

    @Transactional(readOnly = true)
    public SeriesItem getSeries(UUID userId, UUID seriesId) {
        ProducerProfile profile = approvedCreator(userId);
        return toSeriesItem(ownedSeries(seriesId, profile.getProducerProfileId()));
    }

    @Transactional(readOnly = true)
    public List<PodcastItem> listSeriesPodcasts(UUID userId, UUID seriesId) {
        ProducerProfile profile = approvedCreator(userId);
        ownedSeries(seriesId, profile.getProducerProfileId());
        return podcastRepository.findAllBySeries_SeriesId(seriesId).stream()
                .map(this::toPodcastItem).toList();
    }

    @Transactional
    public SeriesItem createSeries(UUID userId, SeriesWrite request) {
        ProducerProfile profile = approvedCreator(userId);
        Category category = activeCategory(request.categoryId());
        String slug = normalizeSlug(request.slug());
        ensureSeriesSlugAvailable(profile.getProducerProfileId(), slug, null);

        Series series = new Series();
        series.setProducerProfile(profile);
        series.setCategory(category);
        series.setTitle(request.title().trim());
        series.setSlug(slug);
        series.setDescription(trimToNull(request.description()));
        series.setCoverUrl(trimToNull(request.coverUrl()));
        series.setStatus("PUBLISHED");
        series.setPublishedAt(Instant.now());
        return toSeriesItem(seriesRepository.save(series));
    }

    @Transactional
    public SeriesItem updateSeries(UUID userId, UUID seriesId, SeriesWrite request) {
        ProducerProfile profile = approvedCreator(userId);
        Series series = ownedSeries(seriesId, profile.getProducerProfileId());
        if ("ARCHIVED".equalsIgnoreCase(series.getStatus())) {
            throw new ResourceConflictException("Series đã lưu trữ, không thể chỉnh sửa.");
        }
        Category category = activeCategory(request.categoryId());
        String slug = normalizeSlug(request.slug());
        ensureSeriesSlugAvailable(profile.getProducerProfileId(), slug, seriesId);

        series.setCategory(category);
        series.setTitle(request.title().trim());
        series.setSlug(slug);
        series.setDescription(trimToNull(request.description()));
        series.setCoverUrl(trimToNull(request.coverUrl()));
        return toSeriesItem(seriesRepository.save(series));
    }

    @Transactional
    public SeriesItem archiveSeries(UUID userId, UUID seriesId) {
        ProducerProfile profile = approvedCreator(userId);
        Series series = ownedSeries(seriesId, profile.getProducerProfileId());
        List<Podcast> podcasts = podcastRepository.findAllBySeries_SeriesId(seriesId);
        podcasts.forEach(podcast -> podcast.setSeries(null));
        podcastRepository.saveAll(podcasts);
        series.setStatus("ARCHIVED");
        series.setPublishedAt(null);
        return toSeriesItem(seriesRepository.save(series));
    }

    @Transactional(readOnly = true)
    public List<PodcastItem> listPodcasts(UUID userId) {
        ProducerProfile profile = approvedCreator(userId);
        return podcastRepository
                .findAllByProducerProfile_ProducerProfileIdOrderByCreatedAtDesc(
                        profile.getProducerProfileId())
                .stream().map(this::toPodcastItem).toList();
    }

    @Transactional(readOnly = true)
    public PodcastItem getPodcast(UUID userId, UUID podcastId) {
        ProducerProfile profile = approvedCreator(userId);
        return toPodcastItem(ownedPodcast(podcastId, profile.getProducerProfileId()), true);
    }

    @Transactional
    public PodcastItem createPodcast(UUID userId, PodcastWrite request) {
        ProducerProfile profile = approvedCreator(userId);
        Category category = activeCategory(request.categoryId());

        Podcast podcast = new Podcast();
        podcast.setProducerProfile(profile);
        podcast.setCategory(category);
        podcast.setSeries(null);
        applyPodcastWrite(podcast, request);
        podcast.setMediaUrl(null);
        podcast.setMediaType(null);
        podcast.setStatus("DRAFT");
        podcast.setPublishedAt(null);
        return toPodcastItem(podcastRepository.save(podcast));
    }

    @Transactional
    public PodcastItem updatePodcast(UUID userId, UUID podcastId, PodcastWrite request) {
        ProducerProfile profile = approvedCreator(userId);
        Podcast podcast = ownedPodcast(podcastId, profile.getProducerProfileId());
        requireEditable(podcast);
        Category category = activeCategory(request.categoryId());

        podcast.setCategory(category);
        applyPodcastWrite(podcast, request);
        return toPodcastItem(podcastRepository.save(podcast));
    }

    @Transactional
    public PodcastItem assignPodcastToSeries(UUID userId, UUID podcastId, UUID seriesId) {
        ProducerProfile profile = approvedCreator(userId);
        Podcast podcast = ownedPodcast(podcastId, profile.getProducerProfileId());
        if ("DELETED".equalsIgnoreCase(podcast.getStatus())) {
            throw new ResourceConflictException("Podcast đã xóa, không thể thêm vào series.");
        }
        Series series = ownedSeries(seriesId, profile.getProducerProfileId());
        ensureSeriesCanReceivePodcast(series);
        podcast.setSeries(series);
        return toPodcastItem(podcastRepository.save(podcast));
    }

    @Transactional
    public PodcastItem removePodcastFromSeries(UUID userId, UUID podcastId) {
        ProducerProfile profile = approvedCreator(userId);
        Podcast podcast = ownedPodcast(podcastId, profile.getProducerProfileId());
        if ("DELETED".equalsIgnoreCase(podcast.getStatus())) {
            throw new ResourceConflictException("Podcast đã xóa, không thể sửa series.");
        }
        podcast.setSeries(null);
        return toPodcastItem(podcastRepository.save(podcast));
    }

    @Transactional
    public PodcastVideoItem uploadPodcastVideo(UUID userId, UUID podcastId, MultipartFile file) {
        ProducerProfile profile = approvedCreator(userId);
        Podcast podcast = ownedPodcast(podcastId, profile.getProducerProfileId());
        requireEditable(podcast);

        MediaUploadResponse media = mediaUploadService.uploadPodcastVideo(file, userId, podcastId);
        podcast.setMediaUrl(media.objectKey());
        podcast.setMediaType(media.contentType());
        podcastRepository.save(podcast);
        return new PodcastVideoItem(podcastId, podcast.getTitle(), podcast.getStatus(), media);
    }

    @Transactional
    public PodcastItem submitPodcast(UUID userId, UUID podcastId) {
        ProducerProfile profile = approvedCreator(userId);
        Podcast podcast = ownedPodcast(podcastId, profile.getProducerProfileId());
        requireEditable(podcast);
        if (podcast.getMediaUrl() == null || podcast.getMediaUrl().isBlank()
                || podcast.getMediaType() == null || !podcast.getMediaType().startsWith("video/")) {
            throw new InvalidFlowRequestException("Hãy upload video cho podcast trước khi gửi duyệt.");
        }
        if (podcast.getDurationSeconds() == null || podcast.getDurationSeconds() <= 0) {
            throw new InvalidFlowRequestException("Thời lượng podcast phải lớn hơn 0.");
        }
        podcast.setStatus("PENDING_REVIEW");
        podcast.setPublishedAt(null);
        return toPodcastItem(podcastRepository.save(podcast));
    }

    @Transactional
    public PodcastItem archivePodcast(UUID userId, UUID podcastId) {
        ProducerProfile profile = approvedCreator(userId);
        Podcast podcast = ownedPodcast(podcastId, profile.getProducerProfileId());
        if ("PENDING_REVIEW".equalsIgnoreCase(podcast.getStatus())) {
            throw new ResourceConflictException("Podcast đang chờ duyệt, không thể lưu trữ.");
        }
        podcast.setStatus("DELETED");
        podcast.setPublishedAt(null);
        return toPodcastItem(podcastRepository.save(podcast));
    }

    Podcast requireOwnedPodcast(UUID userId, UUID podcastId) {
        ProducerProfile profile = approvedCreator(userId);
        return ownedPodcast(podcastId, profile.getProducerProfileId());
    }

    Podcast requireEditableOwnedPodcast(UUID userId, UUID podcastId) {
        Podcast podcast = requireOwnedPodcast(userId, podcastId);
        requireEditable(podcast);
        return podcast;
    }

    private ProducerProfile approvedCreator(UUID userId) {
        AppUser user = appUserRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản."));
        if (user.getIsActive() == null || !user.getIsActive()) {
            throw new ResourceForbiddenException("Tài khoản đã bị vô hiệu hóa.");
        }
        if (user.getRole() == null || !"CREATOR".equalsIgnoreCase(user.getRole().getRoleCode())) {
            throw new ResourceForbiddenException("Chỉ Content Creator mới được dùng chức năng này.");
        }
        ProducerProfile profile = producerProfileRepository.findByUser_UserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Tài khoản chưa có hồ sơ Creator."));
        if (!"APPROVED".equalsIgnoreCase(profile.getVerificationStatus())) {
            throw new ResourceForbiddenException("Hồ sơ Creator chưa được Admin duyệt.");
        }
        return profile;
    }

    private Category activeCategory(UUID categoryId) {
        Category category = categoryRepository.findById(categoryId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy danh mục."));
        if (category.getIsActive() == null || !category.getIsActive()) {
            throw new ResourceConflictException("Danh mục đã bị tắt, không thể sử dụng.");
        }
        return category;
    }

    private Series ownedSeries(UUID seriesId, UUID creatorId) {
        return seriesRepository.findBySeriesIdAndProducerProfile_ProducerProfileId(seriesId, creatorId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy series thuộc kênh của bạn."));
    }

    private Podcast ownedPodcast(UUID podcastId, UUID creatorId) {
        return podcastRepository.findByPodcastIdAndProducerProfile_ProducerProfileId(podcastId, creatorId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy podcast thuộc kênh của bạn."));
    }

    private void ensureSeriesCanReceivePodcast(Series series) {
        if ("ARCHIVED".equalsIgnoreCase(series.getStatus())) {
            throw new ResourceConflictException("Không thể thêm podcast vào series đã lưu trữ.");
        }
    }

    private void ensureSeriesSlugAvailable(UUID creatorId, String slug, UUID currentSeriesId) {
        boolean exists = currentSeriesId == null
                ? seriesRepository.existsByProducerProfile_ProducerProfileIdAndSlugIgnoreCase(creatorId, slug)
                : seriesRepository.existsByProducerProfile_ProducerProfileIdAndSlugIgnoreCaseAndSeriesIdNot(
                        creatorId, slug, currentSeriesId);
        if (exists) {
            throw new ResourceConflictException("Slug series đã được sử dụng trong kênh.");
        }
    }

    private void requireEditable(Podcast podcast) {
        String status = podcast.getStatus() == null ? "" : podcast.getStatus().toUpperCase(Locale.ROOT);
        if (status.equals("APPROVED") || status.equals("PUBLISHED")) {
            podcast.setStatus("DRAFT");
            podcast.setPublishedAt(null);
            return;
        }
        if (!status.equals("DRAFT") && !status.equals("REJECTED")) {
            throw new ResourceConflictException("Podcast đang ở trạng thái không cho phép chỉnh sửa hoặc upload.");
        }
    }

    private void applyPodcastWrite(Podcast podcast, PodcastWrite request) {
        podcast.setTitle(request.title().trim());
        podcast.setDescription(trimToNull(request.description()));
        podcast.setThumbnailUrl(trimToNull(request.thumbnailUrl()));
        podcast.setDurationSeconds(request.durationSeconds());
        podcast.setEpisodeNumber(request.episodeNumber());
        podcast.setIsExclusive(request.resolvedVisibility().isExclusive());
    }

    private String normalizeSlug(String value) {
        String slug = value.trim().toLowerCase(Locale.ROOT)
                .replaceAll("[^\\p{L}\\p{N}]+", "-")
                .replaceAll("^-|-$", "");
        if (slug.isBlank()) {
            throw new InvalidFlowRequestException("Slug không hợp lệ.");
        }
        return slug;
    }

    private String trimToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private SeriesItem toSeriesItem(Series series) {
        return new SeriesItem(
                series.getSeriesId(),
                series.getCategory().getCategoryId(),
                series.getCategory().getName(),
                series.getTitle(),
                series.getSlug(),
                series.getDescription(),
                series.getCoverUrl(),
                series.getStatus(),
                series.getPublishedAt(),
                series.getCreatedAt(),
                series.getUpdatedAt());
    }

    private PodcastItem toPodcastItem(Podcast podcast) {
        return toPodcastItem(podcast, false);
    }

    private PodcastItem toPodcastItem(Podcast podcast, boolean includeVideoUrl) {
        Series series = podcast.getSeries();
        R2PlaybackUrlService.PlaybackUrl video = null;
        if (includeVideoUrl && !"DELETED".equalsIgnoreCase(podcast.getStatus())
                && podcast.getMediaUrl() != null && !podcast.getMediaUrl().isBlank()) {
            video = playbackUrlService.create(podcast.getMediaUrl(), Boolean.TRUE.equals(podcast.getIsExclusive()));
        }
        return new PodcastItem(
                podcast.getPodcastId(),
                series == null ? null : series.getSeriesId(),
                series == null ? null : series.getTitle(),
                podcast.getCategory().getCategoryId(),
                podcast.getCategory().getName(),
                podcast.getTitle(),
                podcast.getDescription(),
                podcast.getMediaUrl(),
                podcast.getMediaType(),
                video == null ? null : video.url(),
                video == null ? null : video.expiresAt(),
                podcast.getThumbnailUrl(),
                podcast.getDurationSeconds(),
                podcast.getEpisodeNumber(),
                podcast.getIsExclusive(),
                com.prmteam7.podcasthistory.enums.PodcastVisibility.fromExclusive(podcast.getIsExclusive()),
                podcast.getStatus(),
                podcast.getPublishedAt(),
                podcast.getCreatedAt(),
                podcast.getUpdatedAt());
    }
}
