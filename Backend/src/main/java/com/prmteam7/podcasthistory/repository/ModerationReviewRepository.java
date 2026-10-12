package com.prmteam7.podcasthistory.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.ModerationReview;

public interface ModerationReviewRepository extends JpaRepository<ModerationReview, UUID> {
}
