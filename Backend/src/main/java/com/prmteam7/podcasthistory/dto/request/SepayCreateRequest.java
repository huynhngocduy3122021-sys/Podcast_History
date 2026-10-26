package com.prmteam7.podcasthistory.dto.request;

import jakarta.validation.constraints.NotNull;
import java.util.UUID;

public record SepayCreateRequest(
    @NotNull(message = "paymentId không được để trống") UUID paymentId) {}
