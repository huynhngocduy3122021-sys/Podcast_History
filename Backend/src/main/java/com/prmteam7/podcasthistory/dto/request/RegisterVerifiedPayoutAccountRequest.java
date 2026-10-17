package com.prmteam7.podcasthistory.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record RegisterVerifiedPayoutAccountRequest(
        @NotBlank @Size(max = 40) String payoutMethod,
        @NotBlank @Size(max = 255) String accountReference,
        @NotBlank @Size(max = 160) String accountMasked,
        @NotBlank @Pattern(regexp = "[A-Za-z]{3}") String currency) {
}
