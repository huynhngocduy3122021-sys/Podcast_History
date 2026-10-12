package com.prmteam7.podcasthistory.repository;

import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.Report;

public interface ReportRepository extends JpaRepository<Report, UUID> {

    Page<Report> findAllByUser_UserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);
}
