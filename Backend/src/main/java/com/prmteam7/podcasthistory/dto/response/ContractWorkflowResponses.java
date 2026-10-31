package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class ContractWorkflowResponses {
    private ContractWorkflowResponses() {}

    public record Request(UUID requestId, String status, BigDecimal budgetAmount,
                          BigDecimal heldAmount, String currency,
                          String requestedTitle, UUID listenerId, String listenerName,
                          UUID creatorProfileId, String creatorChannelName) {}

    public record RequestDetail(UUID requestId, UUID creatorProfileId, String status,
                                String requestedTitle, String description,
                                BigDecimal budgetAmount, BigDecimal remainingHeld,
                                boolean fundsHeld, String currency,
                                String productType, String fileFormat, String duration,
                                String acceptanceCriteria, boolean autoAcceptEnabled,
                                Instant createdAt,
                                UUID listenerId, String listenerName, String listenerAvatarUrl,
                                String creatorChannelName, String creatorAvatarUrl,
                                UUID contractId, String contractStatus) {}

    public record Stage(UUID milestoneId, String name, String description, Instant dueAt,
                        BigDecimal amount, String status) {}

    public record Agreement(UUID requestId, UUID contractId, String contractStatus,
                            int contractVersion, String contentHash, String contentSnapshot,
                            Instant creatorSignedAt, Instant listenerSignedAt,
                            BigDecimal budgetAmount, BigDecimal remainingHeld,
                            List<Stage> milestones) {}

    public record Settlement(UUID milestoneId, UUID paymentId, BigDecimal grossAmount,
                             BigDecimal creatorNet, BigDecimal platformFee,
                             BigDecimal remainingHeld, String status) {}

    public record Termination(UUID contractId, BigDecimal compensationGross,
                              BigDecimal creatorNet, BigDecimal platformFee,
                              BigDecimal refundedToListener, String status) {}

    public record TerminationRequestStatus(UUID disputeId, UUID contractId, String status,
                                           String decision, Instant createdAt,
                                           Instant negotiationEndsAt, Instant resolvedAt,
                                           Instant opponentConfirmedAt, String listenerWinAction) {}

    public record MediaUrl(UUID submissionId, String url, Instant expiresAt) {}
}
