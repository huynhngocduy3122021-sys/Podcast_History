package com.prmteam7.podcasthistory.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "Refresh token hiện tại")
public record RefreshTokenRequest(
        @NotBlank(message = "Refresh token không được để trống")
        @Size(max = 128, message = "Refresh token không hợp lệ")
        String refreshToken) {
}
