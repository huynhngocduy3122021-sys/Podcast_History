package com.prmteam7.podcasthistory.dto.request;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "Thông tin tạo tài khoản Listener")
public record RegisterRequest(
        @NotBlank(message = "Username không được để trống")
        @Size(min = 3, max = 50, message = "Username phải có từ 3 đến 50 ký tự")
        @Schema(example = "podcast_listener")
        String username,

        @NotBlank(message = "Email không được để trống")
        @Email(message = "Email không đúng định dạng")
        @Size(max = 255, message = "Email không được vượt quá 255 ký tự")
        @Schema(example = "listener@example.com")
        String email,

        @NotBlank(message = "Mật khẩu không được để trống")
        @Size(min = 8, max = 72, message = "Mật khẩu phải có từ 8 đến 72 ký tự")
        @Schema(example = "your-password")
        String password,

        @NotBlank(message = "Tên hiển thị không được để trống")
        @Size(max = 120, message = "Tên hiển thị không được vượt quá 120 ký tự")
        @Schema(example = "Podcast Listener")
        String displayName) {
}
