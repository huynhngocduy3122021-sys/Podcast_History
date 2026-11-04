package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.response.AdminResponses.*;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.math.BigDecimal;
import java.util.*;
import org.springframework.data.domain.Page;
import org.springframework.data.jpa.domain.Specification;
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
  private final WalletTransactionRepository walletTransactions;
  private final ContractRepository contracts;

  public AdminDashboardService(
      AdminSupportService support,
      AppUserRepository users,
      ProducerProfileRepository creators,
      PodcastRepository podcasts,
      ReportRepository reports,
      WithdrawalRequestRepository withdrawals,
      ContractDisputeRepository disputes,
      PaymentRepository payments,
      WalletTransactionRepository walletTransactions,
      ContractRepository contracts) {
    this.support = support;
    this.users = users;
    this.creators = creators;
    this.podcasts = podcasts;
    this.reports = reports;
    this.withdrawals = withdrawals;
    this.disputes = disputes;
    this.payments = payments;
    this.walletTransactions = walletTransactions;
    this.contracts = contracts;
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
            .toList(),
        revenueBreakdown());
  }

  @Transactional(readOnly = true)
  public Page<RevenueDetail> revenueDetails(UUID actor, int page, int size) {
    support.actor(actor, false);
    Page<Payment> collected = payments.findAll(collectedPaymentSpec(), AdminSupportService.page(page, size));
    Map<UUID, BigDecimal> fees = new HashMap<>();
    List<UUID> paymentIds = collected.getContent().stream().map(Payment::getPaymentId).toList();
    if (!paymentIds.isEmpty()) {
      for (Object[] row : walletTransactions.platformFeesByPaymentIds(paymentIds)) {
        if (row == null || row.length < 2 || row[0] == null) continue;
        BigDecimal amount = row[1] instanceof BigDecimal value
            ? value
            : new BigDecimal(row[1].toString());
        fees.put((UUID) row[0], amount);
      }
    }
    return collected.map(
        payment -> revenueDetail(payment, fees.getOrDefault(payment.getPaymentId(), BigDecimal.ZERO)));
  }

  private Specification<Payment> collectedPaymentSpec() {
    return (root, query, criteriaBuilder) -> criteriaBuilder.upper(root.get("status"))
        .in(List.of("PAID", "SUCCESS", "COMPLETED"));
  }

  private RevenueDetail revenueDetail(Payment payment, BigDecimal platformFee) {
    String sourceType = "OTHER";
    String sourceLabel = "Khoản thu khác";
    Subscription subscription = payment.getSubscription();
    MembershipPlan membershipPlan = null;
    Contract contract = null;
    ContractStage stage = payment.getContractStage();
    SeriesRequest request = payment.getSeriesRequest();
    ProducerProfile creator = null;
    UUID membershipPlanId = null;
    String membershipPlanName = null;

    if (subscription != null) {
      sourceType = "MEMBERSHIP";
      membershipPlan = subscription.getMembershipPlan();
      creator = membershipPlan == null ? null : membershipPlan.getProducerProfile();
      membershipPlanId = membershipPlan == null ? null : membershipPlan.getMembershipPlanId();
      membershipPlanName = membershipPlan == null ? null : membershipPlan.getName();
      sourceLabel = "Membership" + (membershipPlanName == null ? "" : ": " + membershipPlanName);
    } else if (stage != null) {
      contract = stage.getContract();
      creator = contract == null ? null : contract.getProducerProfile();
      request = contract == null || contract.getSeriesResponse() == null
          ? request
          : contract.getSeriesResponse().getSeriesRequest();
      String method = payment.getPaymentMethod() == null
          ? ""
          : payment.getPaymentMethod().trim().toUpperCase(Locale.ROOT);
      sourceType = switch (method) {
        case "WALLET_ESCROW_DISPUTE" -> "CONTRACT_DISPUTE";
        case "WALLET_ESCROW_COMPENSATION" -> "CONTRACT_COMPENSATION";
        default -> "CONTRACT_STAGE";
      };
      String title = request == null ? null : request.getRequestedTitle();
      sourceLabel = sourceType + (title == null || title.isBlank() ? "" : ": " + title)
          + " / Đợt " + (stage.getStageOrder() == null ? "" : stage.getStageOrder());
    } else if (request != null) {
      creator = request.getProducerProfile();
      contract = contracts.findBySeriesResponse_SeriesRequest_SeriesRequestId(
          request.getSeriesRequestId()).orElse(null);
      String method = payment.getPaymentMethod() == null
          ? ""
          : payment.getPaymentMethod().trim().toUpperCase(Locale.ROOT);
      sourceType = switch (method) {
        case "WALLET_ESCROW_DISPUTE" -> "CONTRACT_DISPUTE";
        case "WALLET_ESCROW_COMPENSATION" -> "CONTRACT_COMPENSATION";
        default -> "REQUEST";
      };
      sourceLabel = sourceType + (request.getRequestedTitle() == null
          || request.getRequestedTitle().isBlank() ? "" : ": " + request.getRequestedTitle());
    }

    AppUser buyer = payment.getUser();
    AppUser creatorUser = creator == null ? null : creator.getUser();
    BigDecimal netRevenue = platformFee;
    return new RevenueDetail(
        payment.getPaymentId(),
        sourceType,
        sourceLabel,
        payment.getAmount(),
        platformFee,
        netRevenue,
        payment.getCurrency(),
        payment.getStatus(),
        payment.getPaymentMethod(),
        payment.getProvider(),
        payment.getProviderTransactionId(),
        payment.getCreatedAt(),
        payment.getPaidAt(),
        buyer == null ? null : buyer.getUserId(),
        buyer == null ? null : buyer.getDisplayName(),
        buyer == null ? null : buyer.getEmail(),
        creator == null ? null : creator.getProducerProfileId(),
        creatorUser == null ? null : creatorUser.getUserId(),
        creatorUser == null ? null : creatorUser.getDisplayName(),
        creator == null ? null : creator.getChannelName(),
        contract == null ? null : contract.getContractId(),
        request == null ? null : request.getSeriesRequestId(),
        request == null ? null : request.getRequestedTitle(),
        stage == null ? null : stage.getContractStageId(),
        stage == null ? null : stage.getStageName(),
        stage == null ? null : stage.getStageOrder(),
        membershipPlanId,
        membershipPlanName);
  }

  private List<RevenueBreakdown> revenueBreakdown() {
    Map<String, BigDecimal> gross = aggregate(payments.collectedByCurrency());
    Map<String, BigDecimal> fees = aggregate(walletTransactions.platformFeesByCurrency());
    Set<String> currencies = new TreeSet<>(gross.keySet());
    currencies.addAll(fees.keySet());
    return currencies.stream()
        .map(currency -> {
          BigDecimal platformFees = fees.getOrDefault(currency, BigDecimal.ZERO);
          return new RevenueBreakdown(
              currency,
              gross.getOrDefault(currency, BigDecimal.ZERO),
              platformFees,
              platformFees);
        })
        .toList();
  }

  private Map<String, BigDecimal> aggregate(List<Object[]> rows) {
    Map<String, BigDecimal> result = new TreeMap<>();
    for (Object[] row : rows) {
      if (row == null || row.length < 2 || row[0] == null) continue;
      String currency = row[0].toString().trim().toUpperCase(Locale.ROOT);
      BigDecimal amount = row[1] instanceof BigDecimal value
          ? value
          : new BigDecimal(row[1].toString());
      result.merge(currency, amount, BigDecimal::add);
    }
    return result;
  }
}
