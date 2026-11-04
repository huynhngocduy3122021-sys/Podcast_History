package com.prmteam7.podcasthistory.dto.request;

import jakarta.validation.Valid;
import com.prmteam7.podcasthistory.enums.ListenerWinAction;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class ContractWorkflowRequests {
    private ContractWorkflowRequests() {}

    public record Create(
            @NotNull UUID idempotencyKey,
            @NotNull UUID creatorProfileId,
            @NotBlank @Size(max = 220) String requestedTitle,
            @NotBlank @Size(max = 5000) String description,
            @NotNull @DecimalMin("1") @Digits(integer = 10, fraction = 0) BigDecimal budgetAmount,
            @NotBlank @Pattern(regexp = "AUDIO|VIDEO") String productType,
            @NotBlank @Size(max = 60) String fileFormat,
            @NotBlank @Size(max = 120) String duration,
            @NotBlank @Size(max = 5000) String acceptanceCriteria,
            boolean autoAcceptEnabled) {}

    public record Stage(
            @NotBlank @Size(max = 150) String name,
            @NotBlank @Size(max = 3000) String description,
            @NotNull Instant dueAt,
            @NotNull @DecimalMin("1") @Digits(integer = 10, fraction = 0) BigDecimal amount) {}

    public record Proposal(
            @NotBlank @Size(max = 5000) String responseText,
            @NotEmpty List<@Valid Stage> milestones) {}

    public record Sign(
            @NotNull Integer contractVersion,
            @NotBlank String contentHash,
            @AssertTrue boolean accepted) {}

    public record Terminate(
            @NotBlank @Size(max = 5000) String reason,
            boolean compensateCurrentStage,
            UUID qualifyingSubmissionId,
            @Size(max = 5000) String evidenceNote) {}

    public record Dispute(@NotBlank @Size(max = 5000) String reason,
                          ListenerWinAction listenerWinAction) {}
}
