package com.prmteam7.podcasthistory.dto.request;

import com.prmteam7.podcasthistory.enums.*;
import jakarta.validation.constraints.*;

public final class AdminRequests {
  private AdminRequests() {}

  public record Note(@NotBlank @Size(max = 5000) String note) {}

  public record UserProfile(
      @NotBlank @Size(max = 120) String displayName,
      @Size(max = 2000) String avatarUrl,
      @Size(max = 5000) String bio) {}

  public record UserAccess(@NotNull Boolean active, @NotBlank @Size(max = 5000) String note) {}

  public record UserVerification(
      @NotNull Boolean verified, @NotBlank @Size(max = 5000) String note) {}

  public record UserRoleChange(@NotNull UserRole role, @NotBlank @Size(max = 5000) String note) {}

  public record StaffCreate(
      @NotBlank @Size(min = 3, max = 50) String username,
      @NotBlank @Email @Size(max = 255) String email,
      @NotBlank @Size(min = 8, max = 72) String password,
      @NotBlank @Size(max = 120) String displayName) {}

  public record ResolveReport(
      @NotNull ReportAction action, @NotBlank @Size(max = 5000) String note) {}

  public record ResolveAppeal(
      @NotNull CaseDecision decision, @NotBlank @Size(max = 5000) String note) {}

  public record ResolveDispute(
      @NotNull DisputeDecision decision, @NotBlank @Size(max = 5000) String note) {}

  public record ApproveWithdrawal(
      @NotNull @AssertTrue Boolean payoutAccountVerified,
      @NotBlank @Size(max = 5000) String note) {}

  public record CompleteWithdrawal(
      @NotBlank @Size(max = 180) String payoutReference, @NotBlank @Size(max = 5000) String note) {}

  public record ReconcilePayment(
      @NotNull ManualPaymentResult result,
      @Size(max = 180) String providerTransactionId,
      @NotBlank @Size(max = 5000) String note) {}

  public record RefundPayment(
      @NotBlank @Size(max = 180) String refundReference, @NotBlank @Size(max = 5000) String note) {}

  public record MembershipPlanWrite(
      @NotNull java.util.UUID creatorId,
      @NotBlank @Size(max = 150) String name,
      @Size(max = 10000) String description,
      @NotNull @DecimalMin("0.01") @Digits(integer = 10, fraction = 2) java.math.BigDecimal price,
      @NotBlank @Pattern(regexp = "[A-Z]{3}") String currency,
      @NotNull @Min(1) @Max(3650) Integer durationDays,
      @NotNull MembershipPlanStatus status) {}
}
