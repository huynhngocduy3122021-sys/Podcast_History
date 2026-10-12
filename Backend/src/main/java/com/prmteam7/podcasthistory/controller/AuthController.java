package com.prmteam7.podcasthistory.controller;

import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.prmteam7.podcasthistory.dto.request.LoginRequest;
import com.prmteam7.podcasthistory.dto.response.LoginResponse;
import com.prmteam7.podcasthistory.dto.request.RefreshTokenRequest;
import com.prmteam7.podcasthistory.dto.request.RegisterRequest;
import com.prmteam7.podcasthistory.dto.response.RegisterResponse;
import com.prmteam7.podcasthistory.exception.InvalidRefreshTokenException;
import com.prmteam7.podcasthistory.service.AuthService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/auth")
@Tag(name = "Authentication", description = "Đăng nhập và xác thực tài khoản")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/login")
    @Operation(summary = "Đăng nhập", description = "Đăng nhập bằng username hoặc email và nhận JWT Bearer token.")
    public LoginResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }

    @PostMapping("/register")
    @Operation(summary = "Tạo tài khoản Listener", description = "Mật khẩu được băm BCrypt trước khi ghi vào database.")
    public ResponseEntity<RegisterResponse> register(@Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(authService.register(request));
    }

    @PostMapping("/refresh")
    @Operation(summary = "Cấp lại cặp token", description = "Refresh token còn hiệu lực sẽ được xoay vòng; token cũ bị vô hiệu hóa.")
    public LoginResponse refresh(@Valid @RequestBody RefreshTokenRequest request) {
        return authService.refresh(request.refreshToken())
                .orElseThrow(InvalidRefreshTokenException::new);
    }

    @PostMapping("/logout")
    @Operation(summary = "Đăng xuất", description = "Thu hồi refresh token hiện tại và các token còn lại trong phiên đó.")
    public ResponseEntity<Void> logout(@Valid @RequestBody RefreshTokenRequest request) {
        authService.logout(request.refreshToken());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/me")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "Lấy thông tin từ JWT", description = "Endpoint được bảo vệ, dùng để kiểm tra Bearer token.")
    public ResponseEntity<Map<String, Object>> currentUser(
            @Parameter(hidden = true) @AuthenticationPrincipal Jwt jwt) {
        return ResponseEntity.status(HttpStatus.OK).body(Map.of(
                "userId", jwt.getClaimAsString("user_id"),
                "username", jwt.getSubject(),
                "email", jwt.getClaimAsString("email"),
                "role", jwt.getClaimAsString("role")));
    }
}
