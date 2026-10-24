package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;

public record ReleaseFundsResponse(
        int releasedMilestones,
        BigDecimal releasedAmount,
        WalletBalanceResponse wallet) {
}
