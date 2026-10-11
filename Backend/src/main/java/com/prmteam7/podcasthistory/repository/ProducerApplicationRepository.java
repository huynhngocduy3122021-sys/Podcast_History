package com.prmteam7.podcasthistory.repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.prmteam7.podcasthistory.model.ProducerApplication;

public interface ProducerApplicationRepository extends JpaRepository<ProducerApplication, UUID> {

    boolean existsByUser_UserIdAndApplicationStatus(UUID userId, String applicationStatus);

    @EntityGraph(attributePaths = "user")
    Optional<ProducerApplication> findFirstByUser_UserIdOrderBySubmittedAtDesc(UUID userId);

    @EntityGraph(attributePaths = "user")
    List<ProducerApplication> findAllByApplicationStatusOrderBySubmittedAtAsc(String applicationStatus);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("""
            select application
            from ProducerApplication application
            join fetch application.user
            where application.producerApplicationId = :applicationId
            """)
    Optional<ProducerApplication> findByIdForUpdate(@Param("applicationId") UUID applicationId);
}
