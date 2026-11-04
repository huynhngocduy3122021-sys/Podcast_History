package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.service.CreatorMembershipPlanService;
import com.prmteam7.podcasthistory.service.CreatorMembershipPlanService.ChannelPlan;
import com.prmteam7.podcasthistory.service.CreatorMembershipPlanService.PlanTemplate;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/creator/membership-plans")
@Tag(name = "Content Creator - channel membership plans")
@SecurityRequirement(name = "bearerAuth")
public class CreatorMembershipPlanController {
  private final CreatorMembershipPlanService service;

  public CreatorMembershipPlanController(CreatorMembershipPlanService service) {
    this.service = service;
  }

  @GetMapping("/templates")
  @Operation(summary = "Xem một gói membership mẫu; CC có thể đặt giá riêng cho kênh")
  public List<PlanTemplate> templates(@AuthenticationPrincipal Jwt jwt) {
    return service.templates(userId(jwt));
  }

  @GetMapping
  @Operation(summary = "Xem các gói membership của kênh mình")
  public List<ChannelPlan> myPlans(@AuthenticationPrincipal Jwt jwt) {
    return service.myPlans(userId(jwt));
  }

  @PutMapping("/templates/{templateCode}/select")
  @Operation(summary = "Chọn gói mẫu duy nhất để mở bán trên kênh")
  public ChannelPlan select(@AuthenticationPrincipal Jwt jwt, @PathVariable String templateCode) {
    return service.select(userId(jwt), templateCode);
  }

  @PutMapping("/{planId}/price")
  @Operation(summary = "Đặt giá riêng cho gói đã chọn; giá mẫu toàn hệ thống không đổi")
  public ChannelPlan updatePrice(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID planId,
      @Valid @RequestBody PriceUpdate body) {
    return service.updatePrice(userId(jwt), planId, body.price());
  }

  public record PriceUpdate(@NotNull @DecimalMin("1000") @Digits(integer = 10, fraction = 0)
      BigDecimal price) {}

  private UUID userId(Jwt jwt) {
    return UUID.fromString(jwt.getClaimAsString("user_id"));
  }
}
