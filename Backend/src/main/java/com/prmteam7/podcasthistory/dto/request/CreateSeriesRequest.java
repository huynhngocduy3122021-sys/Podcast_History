package com.prmteam7.podcasthistory.dto.request;

import java.math.BigDecimal;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record CreateSeriesRequest(
        @jakarta.validation.constraints.NotNull java.util.UUID creatorProfileId,
        @NotBlank @Size(max = 220) String requestedTitle,
        @NotBlank @Size(max = 5000) String description,
        @DecimalMin("0.00") @Digits(integer = 10, fraction = 2) BigDecimal requestFee,
        @Pattern(regexp = "[A-Za-z]{3}") String currency) {
}
