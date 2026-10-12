package com.prmteam7.podcasthistory.controller;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.prmteam7.podcasthistory.dto.request.CreatorApplicationRequest;
import com.prmteam7.podcasthistory.dto.response.CreatorApplicationResponse;
import com.prmteam7.podcasthistory.service.CreatorApplicationService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/creator-applications")
@Tag(name = "Creator applications", description = "Đăng ký Creator, trạng thái lưu tại Creator_profile.verification_status")
@SecurityRequirement(name = "bearerAuth")
public class CreatorApplicationController {

    private final CreatorApplicationService creatorApplicationService;

    public CreatorApplicationController(CreatorApplicationService creatorApplicationService) {
        this.creatorApplicationService = creatorApplicationService;
    }

    @PostMapping
    @Operation(summary = "Gửi hồ sơ đăng ký Creator")
    public ResponseEntity<CreatorApplicationResponse> submit(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody CreatorApplicationRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(creatorApplicationService.submit(userId(jwt), request));
    }

    @GetMapping("/me")
    @Operation(summary = "Xem trạng thái hồ sơ Creator của tôi")
    public CreatorApplicationResponse getMyApplication(@AuthenticationPrincipal Jwt jwt) {
        return creatorApplicationService.getMyLatestApplication(userId(jwt));
    }

    private UUID userId(Jwt jwt) {
        return UUID.fromString(jwt.getClaimAsString("user_id"));
    }
}
