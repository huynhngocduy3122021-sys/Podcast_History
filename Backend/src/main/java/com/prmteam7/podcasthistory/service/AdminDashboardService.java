package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.response.AdminResponses.*;
import com.prmteam7.podcasthistory.repository.*;
import java.math.BigDecimal;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminDashboardService {
  private final AdminSupportService support;
  private final AppUserRepository users;
  private final ProducerProfileRepository creators;
  private final PodcastRepository podcasts;
  private final ReportRepository reports;
  private final WithdrawalRequestRepository withdrawals;
  private final ContractDisputeRepository disputes;
  private final PaymentRepository payments;

  public AdminDashboardService(
      AdminSupportService support,
      AppUserRepository users,
      ProducerProfileRepository creators,
      PodcastRepository podcasts,
      ReportRepository reports,
      WithdrawalRequestRepository withdrawals,
      ContractDisputeRepository disputes,
      PaymentRepository payments) {
    this.support = support;
    this.users = users;
    this.creators = creators;
    this.podcasts = podcasts;
    this.reports = reports;
    this.withdrawals = withdrawals;
    this.disputes = disputes;
    this.payments = payments;
  }

  @Transactional(readOnly = true)
  public Dashboard dashboard(UUID actor) {
    support.actor(actor, false);
    return new Dashboard(
        users.count(),
        users.countByIsActiveTrue(),
        creators.countByVerificationStatusIgnoreCase("APPROVED"),
        creators.countByVerificationStatusIgnoreCase("PENDING"),
        podcasts.count(),
        podcasts.countByStatusIgnoreCase("PENDING_REVIEW"),
        reports.countByStatusIn(List.of("PENDING", "UNDER_REVIEW")),
        withdrawals.countByStatus("PENDING"),
        disputes.countByStatus("OPEN"),
        podcasts.countsByStatus().stream()
            .map(x -> new CountByStatus((String) x[0], ((Number) x[1]).longValue()))
            .toList(),
        payments.collectedByCurrency().stream()
            .map(x -> new Revenue((String) x[0], (BigDecimal) x[1]))
            .toList());
  }
}
