package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.PodcastTranscript;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PodcastTranscriptRepository extends JpaRepository<PodcastTranscript, UUID> {
    Optional<PodcastTranscript> findByPodcast_PodcastIdAndMediaKey(UUID podcastId, String mediaKey);

    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.transaction.annotation.Transactional
    @org.springframework.data.jpa.repository.Query(
            "update PodcastTranscript t set t.status = 'PROCESSING', t.processingStartedAt = :now where t.transcriptId = :id and t.status = 'PENDING'")
    int claim(@org.springframework.data.repository.query.Param("id") UUID id,
            @org.springframework.data.repository.query.Param("now") java.time.Instant now);

    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.transaction.annotation.Transactional
    @org.springframework.data.jpa.repository.Query(value = """
            update "Podcast_Transcript"
            set status = 'FAILED', full_text = null, segments = null,
                error_message = :message, processed_at = :now
            where transcript_id = :id and status = 'PROCESSING'
            """, nativeQuery = true)
    int failPersistence(@org.springframework.data.repository.query.Param("id") UUID id,
            @org.springframework.data.repository.query.Param("message") String message,
            @org.springframework.data.repository.query.Param("now") java.time.Instant now);
}
