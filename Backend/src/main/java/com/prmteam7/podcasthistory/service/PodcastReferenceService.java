package com.prmteam7.podcasthistory.service;

import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

import com.prmteam7.podcasthistory.dto.request.PodcastReferenceRequest;
import com.prmteam7.podcasthistory.dto.response.PodcastReferenceResponse;
import com.prmteam7.podcasthistory.dto.response.ReferenceFileResponse;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.model.PodcastReference;
import com.prmteam7.podcasthistory.repository.PodcastReferenceRepository;
import com.prmteam7.podcasthistory.repository.PodcastRepository;

@Service
public class PodcastReferenceService {
    private static final Logger log = LoggerFactory.getLogger(PodcastReferenceService.class);

    private final PodcastReferenceRepository references;
    private final PodcastRepository podcasts;
    private final CreatorFlowService creatorFlow;
    private final ListenerFlowService listenerFlow;
    private final MediaUploadService uploads;
    private final R2PlaybackUrlService downloadUrls;

    public PodcastReferenceService(PodcastReferenceRepository references, PodcastRepository podcasts,
            CreatorFlowService creatorFlow, ListenerFlowService listenerFlow,
            MediaUploadService uploads, R2PlaybackUrlService downloadUrls) {
        this.references = references;
        this.podcasts = podcasts;
        this.creatorFlow = creatorFlow;
        this.listenerFlow = listenerFlow;
        this.uploads = uploads;
        this.downloadUrls = downloadUrls;
    }

    @Transactional(readOnly = true)
    public List<PodcastReferenceResponse> list(UUID userId, UUID podcastId) {
        creatorFlow.requireOwnedPodcast(userId, podcastId);
        return listItems(podcastId);
    }

    @Transactional(readOnly = true)
    public PodcastReferenceResponse get(UUID userId, UUID podcastId, UUID referenceId) {
        creatorFlow.requireOwnedPodcast(userId, podcastId);
        return response(requireReference(podcastId, referenceId));
    }

    @Transactional
    public PodcastReferenceResponse create(UUID userId, UUID podcastId, PodcastReferenceRequest request) {
        var podcast = creatorFlow.requireEditableOwnedPodcast(userId, podcastId);
        PodcastReference reference = new PodcastReference();
        reference.setPodcast(podcast);
        apply(reference, request);
        return response(references.save(reference));
    }

    @Transactional
    public PodcastReferenceResponse update(
            UUID userId, UUID podcastId, UUID referenceId, PodcastReferenceRequest request) {
        creatorFlow.requireEditableOwnedPodcast(userId, podcastId);
        PodcastReference reference = requireReference(podcastId, referenceId);
        apply(reference, request);
        return response(references.save(reference));
    }

    @Transactional
    public void delete(UUID userId, UUID podcastId, UUID referenceId) {
        creatorFlow.requireEditableOwnedPodcast(userId, podcastId);
        PodcastReference reference = requireReference(podcastId, referenceId);
        cleanupAfterCommit(reference.getFileUrl(), userId, podcastId, referenceId);
        references.delete(reference);
    }

    @Transactional
    public PodcastReferenceResponse uploadPdf(
            UUID userId, UUID podcastId, UUID referenceId, MultipartFile file) {
        creatorFlow.requireEditableOwnedPodcast(userId, podcastId);
        PodcastReference reference = requireReference(podcastId, referenceId);
        String oldKey = reference.getFileUrl();
        String newKey = uploads.uploadPodcastReferencePdf(file, userId, podcastId, referenceId).objectKey();
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCompletion(int status) {
                if (status != STATUS_COMMITTED) {
                    cleanup(newKey, userId, podcastId, referenceId);
                }
            }
        });
        reference.setFileUrl(newKey);
        cleanupAfterCommit(oldKey, userId, podcastId, referenceId);
        return response(references.save(reference));
    }

    @Transactional
    public void deleteFile(UUID userId, UUID podcastId, UUID referenceId) {
        creatorFlow.requireEditableOwnedPodcast(userId, podcastId);
        PodcastReference reference = requireReference(podcastId, referenceId);
        cleanupAfterCommit(reference.getFileUrl(), userId, podcastId, referenceId);
        reference.setFileUrl(null);
        references.save(reference);
    }

    @Transactional(readOnly = true)
    public ReferenceFileResponse download(UUID userId, UUID podcastId, UUID referenceId) {
        creatorFlow.requireOwnedPodcast(userId, podcastId);
        return fileResponse(podcastId, referenceId);
    }

    @Transactional(readOnly = true)
    public List<PodcastReferenceResponse> listForAdmin(UUID podcastId) {
        requirePodcast(podcastId);
        return listItems(podcastId);
    }

    @Transactional(readOnly = true)
    public ReferenceFileResponse downloadForAdmin(UUID podcastId, UUID referenceId) {
        requirePodcast(podcastId);
        return fileResponse(podcastId, referenceId);
    }

    @Transactional(readOnly = true)
    public List<PodcastReferenceResponse> listForListener(UUID userId, UUID podcastId) {
        listenerFlow.requireReferenceAccess(userId, podcastId);
        return listItems(podcastId);
    }

    @Transactional(readOnly = true)
    public ReferenceFileResponse downloadForListener(UUID userId, UUID podcastId, UUID referenceId) {
        listenerFlow.requireReferenceAccess(userId, podcastId);
        return fileResponse(podcastId, referenceId);
    }

    private void requirePodcast(UUID podcastId) {
        if (!podcasts.existsById(podcastId)) {
            throw new ResourceNotFoundException("Không tìm thấy podcast.");
        }
    }

    private List<PodcastReferenceResponse> listItems(UUID podcastId) {
        return references.findAllByPodcast_PodcastIdOrderByCreatedAtAsc(podcastId)
                .stream().map(this::response).toList();
    }

    private PodcastReference requireReference(UUID podcastId, UUID referenceId) {
        return references.findByReferenceIdAndPodcast_PodcastId(referenceId, podcastId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nguồn thuộc podcast này."));
    }

    private ReferenceFileResponse fileResponse(UUID podcastId, UUID referenceId) {
        PodcastReference reference = requireReference(podcastId, referenceId);
        if (reference.getFileUrl() == null || reference.getFileUrl().isBlank()) {
            throw new ResourceNotFoundException("Nguồn này chưa có file PDF.");
        }
        var download = downloadUrls.create(reference.getFileUrl(), true);
        return new ReferenceFileResponse(referenceId, download.url(), download.expiresAt());
    }

    private void apply(PodcastReference reference, PodcastReferenceRequest request) {
        reference.setReferenceType(request.referenceType().name());
        reference.setTitle(request.title().trim());
        reference.setAuthor(trim(request.author()));
        reference.setPublisher(trim(request.publisher()));
        reference.setPublishedYear(request.publishedYear());
        reference.setUrl(trim(request.url()));
        reference.setCitationText(trim(request.citationText()));
    }

    private String trim(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private PodcastReferenceResponse response(PodcastReference reference) {
        return new PodcastReferenceResponse(reference.getReferenceId(), reference.getPodcast().getPodcastId(),
                reference.getReferenceType(), reference.getTitle(), reference.getAuthor(), reference.getPublisher(),
                reference.getPublishedYear(), reference.getUrl(), reference.getFileUrl(),
                reference.getCitationText(), reference.getCreatedAt());
    }

    private void cleanupAfterCommit(String key, UUID userId, UUID podcastId, UUID referenceId) {
        if (key == null || key.isBlank()) {
            return;
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                cleanup(key, userId, podcastId, referenceId);
            }
        });
    }

    private void cleanup(String key, UUID userId, UUID podcastId, UUID referenceId) {
        try {
            uploads.deletePodcastReferenceFile(key, userId, podcastId, referenceId);
        } catch (RuntimeException exception) {
            log.warn("Không xóa được PDF R2 của nguồn {}; cần thử dọn lại object {}", referenceId, key, exception);
        }
    }
}
