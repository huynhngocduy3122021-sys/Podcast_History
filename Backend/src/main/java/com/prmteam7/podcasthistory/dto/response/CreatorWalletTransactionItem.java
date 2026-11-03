package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record CreatorWalletTransactionItem(
        UUID transactionId,
        String type,
        String direction,
        BigDecimal amount,
        String currency,
        String status,
        String referenceCode,
        BigDecimal balanceAfter,
        BigDecimal heldBalanceAfter,
        Instant createdAt,
        String title,
        String description,
        String movement,
        BigDecimal availableBalanceChange,
        BigDecimal heldBalanceChange,
        UUID requestId,
        String requestTitle,
        UUID milestoneId,
        String milestoneName,
        UUID withdrawalId,
        String payoutAccountMasked,
        String membershipPlanName) {}
