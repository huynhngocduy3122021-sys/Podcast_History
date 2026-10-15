package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.util.UUID;

public record WalletBalanceResponse(
        UUID walletId,
        BigDecimal availableBalance,
        BigDecimal heldBalance,
        BigDecimal totalBalance,
        String currency) {
}
