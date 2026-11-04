package com.prmteam7.podcasthistory.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record CreateBankPayoutAccountRequest(
        @NotBlank @Pattern(regexp = "[A-Za-z0-9]{2,20}") String bankCode,
        @NotBlank @Pattern(regexp = "[0-9]{6,30}") String accountNumber,
        @NotBlank @Size(max = 100) String accountHolderName) {
}
