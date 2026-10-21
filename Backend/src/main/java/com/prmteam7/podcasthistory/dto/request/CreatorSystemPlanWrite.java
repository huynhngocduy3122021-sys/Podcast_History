package com.prmteam7.podcasthistory.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.util.List;

public record CreatorSystemPlanWrite(
    @NotBlank @Pattern(regexp = "[A-Za-z][A-Za-z0-9_]{1,59}") String code,
    @NotBlank @Size(max = 150) String name,
    @Size(max = 10000) String description,
    @NotNull @DecimalMin("0.00") @Digits(integer = 10, fraction = 2) BigDecimal price,
    @NotBlank @Pattern(regexp = "[A-Z]{3}") String currency,
    @Min(1) @Max(3650) Integer durationDays,
    @NotBlank @Pattern(regexp = "ACTIVE|INACTIVE") String status,
    @NotNull @Size(max = 30) List<@NotNull @Valid BenefitWrite> benefits) {

  public record BenefitWrite(
      @NotBlank @Pattern(regexp = "[A-Za-z][A-Za-z0-9_]{0,59}") String key,
      @NotBlank @Size(max = 200) String value,
      @Size(max = 500) String description) {}
}
