package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.Report;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ReportRepository
    extends JpaRepository<Report, UUID>,
        org.springframework.data.jpa.repository.JpaSpecificationExecutor<Report> {
  long countByStatusIn(java.util.List<String> statuses);

  @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
  @org.springframework.data.jpa.repository.Query("select r from Report r where r.reportId=:id")
  java.util.Optional<Report> lockById(
      @org.springframework.data.repository.query.Param("id") UUID id);

  @Override
  @org.springframework.data.jpa.repository.EntityGraph(
      attributePaths = {"user", "podcast", "comment", "livestream", "assignedTo"})
  Page<Report> findAll(
      org.springframework.data.jpa.domain.Specification<Report> spec, Pageable page);

  Page<Report> findAllByUser_UserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);
}
