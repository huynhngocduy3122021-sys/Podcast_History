package com.prmteam7.podcasthistory.dto.response;

import java.util.UUID;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "Kết quả đăng nhập")
public record LoginResponse(
        String accessToken,
        String refreshToken,
        String tokenType,
        long expiresIn,
        long refreshExpiresIn,
        UserSummary user) {

    @Schema(description = "Thông tin công khai của tài khoản")
    public record UserSummary(
            UUID id,
            String username,
            String email,
            String displayName,
            String role) {
    }
}
