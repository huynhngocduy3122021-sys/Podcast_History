package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record CreatorSystemSubscriptionView(
    String planCode,
    UUID planId,
    String planName,
    Instant startAt,
    Instant endAt,
    Long uploadLimit,
    long uploadsUsed,
    Long uploadsRemaining,
    boolean canLivestream,
    UUID subscriptionId,
    BigDecimal lastPaymentAmount,
    String lastPaymentStatus,
    String lastPaymentReference,
    List<CreatorSystemPlanView.BenefitView> benefits) {}
