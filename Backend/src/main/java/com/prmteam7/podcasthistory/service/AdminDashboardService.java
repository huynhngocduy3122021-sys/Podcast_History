package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.response.AdminResponses.*;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import jakarta.persistence.EntityManager;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
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
  private final CheckoutPaymentRepository checkouts;
  private final EntityManager entityManager;

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
      ContractRepository contracts,
      CheckoutPaymentRepository checkouts,
      EntityManager entityManager) {
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
    this.checkouts = checkouts;
    this.entityManager = entityManager;
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
        collectedByCurrency().entrySet().stream()
            .map(x -> new Revenue(x.getKey(), x.getValue()))
            .toList(),
        revenueBreakdown());
  }

  @Transactional(readOnly = true)
  public Page<RevenueDetail> revenueDetails(UUID actor, int page, int size) {
    support.actor(actor, false);
    Pageable pageable = AdminSupportService.page(page, size);
    // Page both sources in the database; a paid creator checkout is not a Payment row.
    @SuppressWarnings("unchecked")
    List<Object[]> rows = entityManager.createNativeQuery("""
        select id, kind from (
          select payment_id as id, 'PAYMENT' as kind, created_at
          from "Payment" where upper(status) in ('PAID', 'SUCCESS', 'COMPLETED')
          union all
          select checkout_id as id, 'CREATOR_PLAN' as kind, created_at
          from "Checkout_payment"
          where purpose = 'CREATOR_PLAN' and upper(status) in ('PAID', 'SUCCESS', 'COMPLETED')
        ) revenue order by created_at desc, id desc
        """)
        .setFirstResult(Math.toIntExact(pageable.getOffset()))
        .setMaxResults(pageable.getPageSize())
        .getResultList();
    List<UUID> paymentIds = rows.stream()
        .filter(row -> "PAYMENT".equals(row[1]))
        .map(row -> (UUID) row[0]).toList();
    List<UUID> checkoutIds = rows.stream()
        .filter(row -> "CREATOR_PLAN".equals(row[1]))
        .map(row -> (UUID) row[0]).toList();
    Map<UUID, Payment> paymentById = new HashMap<>();
    payments.findAllById(paymentIds).forEach(payment -> paymentById.put(payment.getPaymentId(), payment));
    Map<UUID, CheckoutPayment> checkoutById = new HashMap<>();
    checkouts.findAllById(checkoutIds).forEach(checkout -> checkoutById.put(checkout.getCheckoutId(), checkout));
    Map<UUID, BigDecimal> fees = new HashMap<>();
    if (!paymentIds.isEmpty()) {
      for (Object[] row : walletTransactions.platformFeesByPaymentIds(paymentIds)) {
        if (row == null || row.length < 2 || row[0] == null) continue;
        BigDecimal amount = row[1] instanceof BigDecimal value
            ? value
            : new BigDecimal(row[1].toString());
        fees.put((UUID) row[0], amount);
      }
    }
    List<RevenueDetail> details = rows.stream().map(row -> {
      UUID id = (UUID) row[0];
      if ("CREATOR_PLAN".equals(row[1])) return creatorPlanDetail(checkoutById.get(id));
      return revenueDetail(paymentById.get(id), fees.getOrDefault(id, BigDecimal.ZERO));
    }).toList();
    long total = payments.count(collectedPaymentSpec())
        + checkouts.countByPurposeAndStatusIn("CREATOR_PLAN", List.of("PAID", "SUCCESS", "COMPLETED"));
    return new PageImpl<>(details, pageable, total);
  }

  private RevenueDetail creatorPlanDetail(CheckoutPayment checkout) {
    CreatorSystemSubscription subscription = checkout.getCreatorSubscription();
    CreatorSystemPlan plan = subscription.getPlan();
    ProducerProfile creator = subscription.getProducerProfile();
    AppUser buyer = checkout.getUser();
    String sourceLabel = "Gói Premium CC: " + plan.getName();
    boolean walletPayment = checkout.getPaymentCode().startsWith("WALLET:");
    String paymentMethod = walletPayment ? "WALLET" : "SEPAY";
    String paymentMethodLabel = walletPayment ? "Ví CC" : "Chuyển khoản SePay";
    return new RevenueDetail(null, "CREATOR_PLAN", sourceLabel, checkout.getAmount(),
        checkout.getAmount(), checkout.getAmount(), checkout.getCurrency(), checkout.getStatus(),
        paymentMethod, paymentMethod, checkout.getProviderTransactionId(), checkout.getCreatedAt(),
        checkout.getPaidAt(), buyer.getUserId(), buyer.getDisplayName(), buyer.getEmail(),
        creator.getProducerProfileId(), buyer.getUserId(), buyer.getDisplayName(),
        creator.getChannelName(), null, null, null, null, null, null, null, null,
        "Gói Premium của CC", paymentStatusLabel(checkout.getStatus()), paymentMethodLabel,
        BigDecimal.ZERO, new BigDecimal("100"),
        "Số tiền CC trả để mua gói Premium mở quyền cho kênh.",
        "Toàn bộ tiền mua gói Premium là doanh thu nền tảng (100%).",
        "CC không nhận khoản chi trả từ giao dịch mua gói này.",
        "CC thanh toán gói Premium " + plan.getName() + " bằng " + paymentMethodLabel + "; app nhận 100%.",
        checkout.getCheckoutId(), plan.getPlanId(), plan.getName());
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
    BigDecimal amount = payment.getAmount() == null ? BigDecimal.ZERO : payment.getAmount();
    BigDecimal creatorNetAmount = amount.subtract(platformFee);
    BigDecimal platformFeePercent = amount.signum() == 0
        ? BigDecimal.ZERO.setScale(2)
        : platformFee.multiply(BigDecimal.valueOf(100))
            .divide(amount, 2, RoundingMode.HALF_UP);
    String sourceTypeLabel = sourceTypeLabel(sourceType);
    String statusLabel = paymentStatusLabel(payment.getStatus());
    String paymentMethodLabel = paymentMethodLabel(payment.getPaymentMethod());
    String amountDescription = "Tổng tiền giao dịch trước khi chia phí nền tảng.";
    String platformFeeDescription = platformFeePercent.signum() == 0
        ? "Chưa ghi nhận phí nền tảng cho giao dịch này."
        : "Phí nền tảng app giữ lại (" + platformFeePercent.stripTrailingZeros().toPlainString()
            + "%).";
    String creatorNetDescription = "Số tiền CC thực nhận sau khi trừ phí nền tảng.";
    String paymentDescription = paymentDescription(sourceType, payment.getPaymentMethod(),
        sourceLabel, platformFeePercent);
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
        membershipPlanName,
        sourceTypeLabel,
        statusLabel,
        paymentMethodLabel,
        creatorNetAmount,
        platformFeePercent,
        amountDescription,
        platformFeeDescription,
        creatorNetDescription,
        paymentDescription,
        null, null, null);
  }

  private List<RevenueBreakdown> revenueBreakdown() {
    Map<String, BigDecimal> gross = collectedByCurrency();
    Map<String, BigDecimal> fees = aggregate(walletTransactions.platformFeesByCurrency());
    aggregate(checkouts.collectedCreatorPlansByCurrency())
        .forEach((currency, amount) -> fees.merge(currency, amount, BigDecimal::add));
    Set<String> currencies = new TreeSet<>(gross.keySet());
    currencies.addAll(fees.keySet());
    return currencies.stream()
        .map(currency -> {
          BigDecimal platformFees = fees.getOrDefault(currency, BigDecimal.ZERO);
          return new RevenueBreakdown(
              currency,
              gross.getOrDefault(currency, BigDecimal.ZERO),
              platformFees,
              platformFees,
              "Tổng Payment và checkout gói Premium CC đã quyết toán; không phải doanh thu ròng của app.",
              "Phí nền tảng đã ghi nhận cộng toàn bộ tiền gói Premium CC đã thanh toán.",
              "Doanh thu ròng của app, hiện bằng phí nền tảng đã ghi nhận.");
        })
        .toList();
  }

  private Map<String, BigDecimal> collectedByCurrency() {
    Map<String, BigDecimal> result = aggregate(payments.collectedByCurrency());
    aggregate(checkouts.collectedCreatorPlansByCurrency())
        .forEach((currency, amount) -> result.merge(currency, amount, BigDecimal::add));
    return result;
  }

  private String sourceTypeLabel(String sourceType) {
    return switch (sourceType) {
      case "MEMBERSHIP" -> "Gói thành viên";
      case "CONTRACT_STAGE" -> "Đợt hợp đồng";
      case "CONTRACT_DISPUTE" -> "Quyết toán tranh chấp hợp đồng";
      case "CONTRACT_COMPENSATION" -> "Bồi thường hợp đồng";
      case "REQUEST" -> "Yêu cầu podcast";
      default -> "Khoản thu khác";
    };
  }

  private String paymentStatusLabel(String status) {
    if (status == null) return "Chưa xác định";
    return switch (status.trim().toUpperCase(Locale.ROOT)) {
      case "PAID", "SUCCESS", "COMPLETED" -> "Đã thu và quyết toán";
      case "PENDING", "PROCESSING" -> "Đang chờ xử lý";
      case "FAILED", "CANCELLED" -> "Thất bại hoặc đã hủy";
      case "REFUNDED" -> "Đã hoàn tiền";
      default -> status;
    };
  }

  private String paymentMethodLabel(String method) {
    if (method == null || method.isBlank()) return "Không xác định";
    return switch (method.trim().toUpperCase(Locale.ROOT)) {
      case "WALLET_ESCROW" -> "Ví Listener - tiền ký quỹ hợp đồng";
      case "WALLET_ESCROW_DISPUTE" -> "Ví Listener - quyết toán tranh chấp";
      case "WALLET_ESCROW_COMPENSATION" -> "Ví Listener - bồi thường hợp đồng";
      case "SEPAY" -> "Chuyển khoản SePay";
      case "WALLET" -> "Ví người dùng";
      default -> method;
    };
  }

  private String paymentDescription(String sourceType, String method, String sourceLabel,
      BigDecimal feePercent) {
    String displaySource = sourceTypeLabel(sourceType);
    String detail = sourceLabel == null ? "" : sourceLabel;
    String prefix = sourceType + ":";
    if (detail.startsWith(prefix)) detail = detail.substring(prefix.length()).trim();
    String methodLabel = paymentMethodLabel(method).toLowerCase(Locale.ROOT);
    String fee = feePercent.signum() == 0
        ? "không ghi nhận phí nền tảng"
        : "app giữ phí nền tảng " + feePercent.stripTrailingZeros().toPlainString() + "%";
    return displaySource + (detail.isBlank() ? "" : " - " + detail)
        + ": Listener thanh toán bằng " + methodLabel + "; " + fee + ".";
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
