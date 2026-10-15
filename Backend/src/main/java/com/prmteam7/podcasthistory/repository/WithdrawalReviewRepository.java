package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.WithdrawalReview;
import java.util.UUID;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.repository.JpaRepository;

public interface WithdrawalReviewRepository extends JpaRepository<WithdrawalReview, UUID> {
  Page<WithdrawalReview> findAllByWithdrawalRequest_WithdrawalRequestIdOrderByReviewedAtDesc(
      UUID id, Pageable page);
}
