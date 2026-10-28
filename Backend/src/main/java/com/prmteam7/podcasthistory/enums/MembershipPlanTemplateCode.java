package com.prmteam7.podcasthistory.enums;

import java.math.BigDecimal;

/**
 * The fixed membership tiers that every approved channel receives.
 *
 * <p>The price is intentionally part of the backend definition so a creator does not have to
 * create a plan or enter a price before memberships can be sold.
 */
public enum MembershipPlanTemplateCode {
  BASIC_25K("Gói thành viên 25K", new BigDecimal("25000")),
  STANDARD_50K("Gói thành viên 50K", new BigDecimal("50000")),
  PREMIUM_75K("Gói thành viên 75K", new BigDecimal("75000"));

  public static final int DEFAULT_DURATION_DAYS = 30;
  public static final String CURRENCY = "VND";
  public static final String PRIVATE_VIDEO_BENEFIT = "Member được xem video private của kênh.";

  private final String displayName;
  private final BigDecimal price;

  MembershipPlanTemplateCode(String displayName, BigDecimal price) {
    this.displayName = displayName;
    this.price = price;
  }

  public String getDisplayName() {
    return displayName;
  }

  public BigDecimal getPrice() {
    return price;
  }
}
