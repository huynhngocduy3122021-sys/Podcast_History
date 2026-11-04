package com.prmteam7.podcasthistory.enums;

import java.math.BigDecimal;
import java.util.Set;

/**
 * The single membership template that every approved channel can select.
 *
 * <p>The suggested price is only a starting point. A creator can change the price for their own
 * channel without changing this system-wide template.
 */
public enum MembershipPlanTemplateCode {
  DEFAULT("Gói thành viên", new BigDecimal("25000"));

  /** Template codes from the previous three-tier rollout. They are kept only for safe data
   * migration; they are never returned as selectable templates again. */
  private static final Set<String> LEGACY_CODES = Set.of(
      "BASIC_25K", "STANDARD_50K", "PREMIUM_75K");

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

  public static boolean isLegacyCode(String code) {
    return code != null && LEGACY_CODES.contains(code.trim().toUpperCase(java.util.Locale.ROOT));
  }
}
