package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.AiModerationResult;
import java.util.Optional;
import java.util.UUID;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AiModerationResultRepository extends JpaRepository<AiModerationResult, UUID> {
    Page<AiModerationResult> findAllByPodcast_PodcastIdOrderByCreatedAtDesc(
            UUID podcastId, Pageable pageable);

    List<AiModerationResult> findAllByPodcast_PodcastIdAndSourceHashAndMediaKeyOrderByCreatedAtDesc(
            UUID podcastId, String sourceHash, String mediaKey);

    Optional<AiModerationResult> findFirstByPodcast_PodcastIdAndStatusAndSourceHashOrderByCreatedAtDesc(
            UUID podcastId, String status, String sourceHash);

    Optional<AiModerationResult> findFirstByPodcast_PodcastIdAndStatusAndSourceHashAndTranscript_TranscriptIdAndTranscriptHashOrderByCreatedAtDesc(
            UUID podcastId, String status, String sourceHash, UUID transcriptId, String transcriptHash);

    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.transaction.annotation.Transactional
    @org.springframework.data.jpa.repository.Query(
            "update AiModerationResult r set r.status = 'PROCESSING' where r.moderationResultId = :id and r.status = 'PENDING'")
    int claim(@org.springframework.data.repository.query.Param("id") UUID id);

    List<AiModerationResult> findAllByPodcast_PodcastIdAndStatusAndMediaKeyOrderByCreatedAtDesc(
            UUID podcastId, String status, String mediaKey);
}
