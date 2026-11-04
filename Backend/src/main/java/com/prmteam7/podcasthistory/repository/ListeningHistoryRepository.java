package com.prmteam7.podcasthistory.repository;

import java.util.Optional;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.ListeningHistory;

public interface ListeningHistoryRepository extends JpaRepository<ListeningHistory, UUID> {

    @org.springframework.data.jpa.repository.Query("""
            select history.podcast.podcastId,
                   coalesce(sum(coalesce(history.listenCount, 1)), 0)
            from ListeningHistory history
            where history.podcast.podcastId in :podcastIds
              and history.user.userId <> history.podcast.producerProfile.user.userId
            group by history.podcast.podcastId
            """)
    List<Object[]> sumListenCountsByPodcastIds(
            @org.springframework.data.repository.query.Param("podcastIds") Collection<UUID> podcastIds);

    @org.springframework.data.jpa.repository.Query("""
            select coalesce(sum(coalesce(history.listenCount, 1)), 0)
            from ListeningHistory history
            where history.podcast.producerProfile.producerProfileId = :creatorId
              and upper(history.podcast.status) <> 'DELETED'
              and history.user.userId <> history.podcast.producerProfile.user.userId
            """)
    long countByCreator(@org.springframework.data.repository.query.Param("creatorId") UUID creatorId);

    @org.springframework.data.jpa.repository.Query("""
            select count(history)
            from ListeningHistory history
            where history.podcast.producerProfile.producerProfileId = :creatorId
              and upper(history.podcast.status) <> 'DELETED'
              and history.lastListenedAt >= :from
              and history.lastListenedAt < :to
            """)
    long countByCreatorBetween(
            @org.springframework.data.repository.query.Param("creatorId") UUID creatorId,
            @org.springframework.data.repository.query.Param("from") Instant from,
            @org.springframework.data.repository.query.Param("to") Instant to);

    @org.springframework.data.jpa.repository.Query("""
            select history.lastListenedAt
            from ListeningHistory history
            where history.podcast.producerProfile.producerProfileId = :creatorId
              and upper(history.podcast.status) <> 'DELETED'
              and history.lastListenedAt >= :from
              and history.lastListenedAt < :to
            """)
    List<Instant> findListenTimes(
            @org.springframework.data.repository.query.Param("creatorId") UUID creatorId,
            @org.springframework.data.repository.query.Param("from") Instant from,
            @org.springframework.data.repository.query.Param("to") Instant to);

    Optional<ListeningHistory> findByUser_UserIdAndPodcast_PodcastId(UUID userId, UUID podcastId);

    @org.springframework.data.jpa.repository.EntityGraph(attributePaths = {"podcast"})
    Page<ListeningHistory> findAllByUser_UserIdOrderByLastListenedAtDesc(UUID userId, Pageable pageable);
}
