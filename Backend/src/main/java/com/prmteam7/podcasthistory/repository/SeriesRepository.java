package com.prmteam7.podcasthistory.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.Series;

public interface SeriesRepository extends JpaRepository<Series, UUID> {

    @EntityGraph(attributePaths = {"category", "producerProfile"})
    List<Series> findAllByProducerProfile_ProducerProfileIdOrderByCreatedAtDesc(UUID producerProfileId);

    @EntityGraph(attributePaths = {"category", "producerProfile"})
    Optional<Series> findBySeriesIdAndProducerProfile_ProducerProfileId(
            UUID seriesId, UUID producerProfileId);

    boolean existsByProducerProfile_ProducerProfileIdAndSlugIgnoreCase(UUID producerProfileId, String slug);

    boolean existsByProducerProfile_ProducerProfileIdAndSlugIgnoreCaseAndSeriesIdNot(
            UUID producerProfileId, String slug, UUID seriesId);
}
