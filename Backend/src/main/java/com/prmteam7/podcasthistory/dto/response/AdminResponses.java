package com.prmteam7.podcasthistory.dto.response;

import com.prmteam7.podcasthistory.dto.response.CreatorResponses.PodcastReviewItem;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class AdminResponses {
  private AdminResponses() {}

  public record CountByStatus(String status, long count) {}

  public record Revenue(String currency, BigDecimal amount) {}

  public record Dashboard(
      long users,
      long activeUsers,
      long creators,
      long pendingCreators,
      long podcasts,
      long pendingPodcasts,
      long pendingReports,
      long pendingWithdrawals,
      long openDisputes,
      List<CountByStatus> podcastStatuses,
      List<Revenue> collectedPayments) {}

  public record UserItem(
      UUID userId,
      String username,
      String email,
      String displayName,
      String avatarUrl,
      String bio,
      String role,
      boolean active,
      boolean verified,
      Instant createdAt,
      Instant lastLoginAt) {}

  public record ReviewItem(
      UUID reviewId,
      UUID reviewerId,
      String reviewerName,
      String decision,
      String note,
      Instant reviewedAt) {}

  public record PodcastDetail(PodcastReviewItem podcast, List<ReviewItem> reviews) {}

  public record Preview(UUID podcastId, String videoUrl, Instant expiresAt) {}

  public record ReportItem(
      UUID reportId,
      UUID reporterId,
      String reporterName,
      String targetType,
      UUID targetId,
      String reasonCode,
      String description,
      String status,
      UUID assigneeId,
      Instant createdAt,
      Instant resolvedAt,
      List<ReviewItem> reviews) {}

  public record AppealItem(
      UUID appealId,
      UUID podcastId,
      UUID applicantId,
      String reason,
      String status,
      String note,
      UUID reviewerId,
      Instant createdAt,
      Instant resolvedAt) {}

  public record DisputeItem(
      UUID disputeId,
      UUID contractId,
      UUID openedById,
      String reason,
      String previousContractStatus,
      String status,
      String decision,
      String note,
      UUID reviewerId,
      Instant createdAt,
      Instant resolvedAt,
      Instant responseDeadlineAt,
      Instant opponentConfirmedAt,
      String listenerWinAction,
      UUID listenerId,
      String listenerName,
      String listenerAvatarUrl,
      UUID creatorId,
      String creatorName,
      String creatorChannelName,
      String creatorAvatarUrl,
      UUID requestId,
      String requestTitle,
      String openedByName,
      String reviewerName) {}

  public record StageItem(UUID stageId, String name, int order, String status) {}

  public record ContractItem(
      UUID contractId,
      UUID listenerId,
      UUID creatorId,
      String status,
      Instant createdAt,
      List<StageItem> stages,
      UUID requestId,
      String requestTitle,
      String listenerName,
      String listenerAvatarUrl,
      UUID creatorUserId,
      String creatorName,
      String creatorChannelName,
      String creatorAvatarUrl) {}

  public record PaymentItem(
      UUID paymentId,
      UUID userId,
      UUID subscriptionId,
      UUID requestId,
      UUID stageId,
      BigDecimal amount,
      String currency,
      String status,
      String provider,
      String providerTransactionId,
      Instant createdAt,
      Instant paidAt,
      String refundReference,
      Instant refundedAt) {}

  public record WithdrawalItem(
      UUID withdrawalId,
      UUID creatorId,
      UUID walletId,
      BigDecimal amount,
      String currency,
      String payoutMethod,
      String payoutAccountMasked,
      String status,
      boolean fundsReserved,
      String payoutReference,
      String note,
      Instant requestedAt,
      Instant processedAt) {}

  public record WithdrawalReviewItem(
      UUID reviewId, UUID reviewerId, String decision, String note, Instant reviewedAt) {}

  public record WalletItem(
      UUID walletId,
      UUID userId,
      String username,
      String email,
      String displayName,
      String role,
      Boolean active,
      Boolean verified,
      BigDecimal availableBalance,
      BigDecimal heldBalance,
      BigDecimal totalBalance,
      String currency,
      String status,
      Instant createdAt,
      Instant updatedAt) {}

  public record TransactionItem(
      UUID transactionId,
      UUID walletId,
      UUID withdrawalId,
      UUID paymentId,
      String type,
      String direction,
      BigDecimal amount,
      String currency,
      String status,
      String referenceCode,
      BigDecimal balanceAfter,
      Instant createdAt) {}

  public record AuditItem(
      UUID auditId,
      UUID actorId,
      String action,
      String resourceType,
      UUID resourceId,
      String note,
      Instant createdAt) {}

  public record NotificationItem(
      UUID notificationId,
      String type,
      String title,
      String message,
      boolean read,
      Instant createdAt,
      Instant readAt,
      tools.jackson.databind.JsonNode payload) {}

  public record PlanItem(
      UUID planId,
      UUID creatorId,
      String name,
      String description,
      BigDecimal price,
      String currency,
      int durationDays,
      String status) {}
}
