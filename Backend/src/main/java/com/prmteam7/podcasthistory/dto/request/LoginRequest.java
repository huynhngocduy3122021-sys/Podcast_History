package com.prmteam7.podcasthistory.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "Thông tin đăng nhập bằng username hoặc email")
public record LoginRequest(
        @NotBlank(message = "Vui lòng nhập username hoặc email")
        @Size(max = 255, message = "Username/email không được vượt quá 255 ký tự")
        @Schema(example = "listener@example.com")
        String identifier,

        @NotBlank(message = "Vui lòng nhập mật khẩu")
        @Size(max = 72, message = "Mật khẩu không được vượt quá 72 ký tự")
        @Schema(example = "your-password")
        String password) {
}
