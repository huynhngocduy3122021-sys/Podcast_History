package com.prmteam7.podcasthistory.repository;

import java.util.Optional;
import java.util.UUID;
import java.util.List;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.prmteam7.podcasthistory.model.Podcast;

public interface PodcastRepository extends JpaRepository<Podcast, UUID> {

    @EntityGraph(attributePaths = {"series", "category", "producerProfile", "producerProfile.user", "producerProfile.user.role"})
    Optional<Podcast> findByPodcastId(UUID podcastId);

    @EntityGraph(attributePaths = {"series", "category", "producerProfile"})
    List<Podcast> findAllByProducerProfile_ProducerProfileIdOrderByCreatedAtDesc(UUID creatorId);

    @EntityGraph(attributePaths = {"series", "category", "producerProfile"})
    Optional<Podcast> findByPodcastIdAndProducerProfile_ProducerProfileId(UUID podcastId, UUID creatorId);

    @EntityGraph(attributePaths = {"series", "category", "producerProfile"})
    List<Podcast> findAllBySeries_SeriesId(UUID seriesId);

    @EntityGraph(attributePaths = {"series", "category", "producerProfile"})
    List<Podcast> findAllByStatusIgnoreCaseOrderByUpdatedAtAsc(String status);

    @EntityGraph(attributePaths = {"series", "category", "producerProfile"})
    List<Podcast> findAllByOrderByCreatedAtDesc();

    @EntityGraph(attributePaths = {"series", "category", "producerProfile"})
    List<Podcast> findAllByStatusIgnoreCaseOrderByCreatedAtDesc(String status);

    @Query("""
            select podcast from Podcast podcast
            join podcast.producerProfile creator
            join podcast.category category
            left join podcast.series series
            where upper(podcast.status) in ('PUBLISHED', 'APPROVED')
              and upper(creator.verificationStatus) = 'APPROVED'
              and category.isActive = true
              and (:categoryId is null or category.categoryId = :categoryId)
              and (:creatorId is null or creator.producerProfileId = :creatorId)
              and (:seriesId is null or series.seriesId = :seriesId)
              and (:query is null
                   or lower(podcast.title) like :query
                   or lower(coalesce(podcast.description, '')) like :query
                   or lower(coalesce(series.title, '')) like :query
                   or lower(creator.channelName) like :query)
            """)
    Page<Podcast> searchPublished(
            @Param("query") String query,
            @Param("categoryId") UUID categoryId,
            @Param("creatorId") UUID creatorId,
            @Param("seriesId") UUID seriesId,
            Pageable pageable);

    @Query("""
            select podcast from Podcast podcast
            join fetch podcast.producerProfile creator
            join fetch podcast.category category
            left join fetch podcast.series
            where podcast.podcastId = :podcastId
              and upper(podcast.status) in ('PUBLISHED', 'APPROVED')
              and upper(creator.verificationStatus) = 'APPROVED'
              and category.isActive = true
            """)
    Optional<Podcast> findPublishedById(@Param("podcastId") UUID podcastId);
}
