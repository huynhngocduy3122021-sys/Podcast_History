package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.response.AdminResponses.Dashboard;
import com.prmteam7.podcasthistory.dto.response.AdminResponses.RevenueDetail;
import com.prmteam7.podcasthistory.service.AdminDashboardService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/admin/dashboard")
@Tag(name = "Admin - dashboard", description = "Admin và Staff cùng xem dashboard")
@SecurityRequirement(name = "bearerAuth")
public class AdminDashboardController {
  private final AdminDashboardService service;

  public AdminDashboardController(AdminDashboardService service) {
    this.service = service;
  }

  @GetMapping
  @Operation(summary = "Tổng quan người dùng, nội dung, báo cáo và thanh toán theo tiền tệ")
  public Dashboard get(@AuthenticationPrincipal Jwt jwt) {
    return service.dashboard(UUID.fromString(jwt.getClaimAsString("user_id")));
  }

  @GetMapping("/revenue-details")
  @Operation(summary = "Chi tiết từng khoản thu theo membership, hợp đồng, đợt và gói Premium CC")
  public Page<RevenueDetail> revenueDetails(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return service.revenueDetails(
        UUID.fromString(jwt.getClaimAsString("user_id")), page, size);
  }
}
