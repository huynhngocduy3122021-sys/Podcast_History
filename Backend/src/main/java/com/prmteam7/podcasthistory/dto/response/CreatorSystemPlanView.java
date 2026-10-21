package com.prmteam7.podcasthistory.dto.response;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record CreatorSystemPlanView(
    UUID planId,
    String code,
    String name,
    String description,
    BigDecimal price,
    String currency,
    Integer durationDays,
    String status,
    List<BenefitView> benefits) {
  public record BenefitView(String key, String value, String description) {}
}
