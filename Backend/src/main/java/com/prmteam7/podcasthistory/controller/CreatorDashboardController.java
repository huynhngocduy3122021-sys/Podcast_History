package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.response.CreatorDashboardResponse;
import com.prmteam7.podcasthistory.service.CreatorDashboardService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/creator/dashboard")
@Tag(name = "Content Creator - dashboard")
@SecurityRequirement(name = "bearerAuth")
public class CreatorDashboardController {

    private final CreatorDashboardService dashboardService;

    public CreatorDashboardController(CreatorDashboardService dashboardService) {
        this.dashboardService = dashboardService;
    }

    @GetMapping
    @Operation(
            summary = "Lấy dữ liệu dashboard của Content Creator",
            description = "Trả hồ sơ kênh, số liệu tháng, biểu đồ tăng trưởng, podcast gần đây và yêu cầu mới.")
    public CreatorDashboardResponse getDashboard(
            @AuthenticationPrincipal Jwt jwt,
            @Parameter(description = "Khoảng biểu đồ: 7d, 4w hoặc 12m")
            @RequestParam(defaultValue = "7d") String period) {
        return dashboardService.getDashboard(userId(jwt), period);
    }

    private UUID userId(Jwt jwt) {
        return UUID.fromString(jwt.getClaimAsString("user_id"));
    }
}
