package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.response.CreatorSystemPlanView;
import com.prmteam7.podcasthistory.dto.response.CreatorSystemSubscriptionView;
import com.prmteam7.podcasthistory.dto.response.CheckoutPaymentView;
import com.prmteam7.podcasthistory.service.CreatorSystemPlanService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/creator/system-plans")
@Tag(name = "Content Creator - system subscription")
@SecurityRequirement(name = "bearerAuth")
public class CreatorSystemPlanController {
  private final CreatorSystemPlanService service;

  public CreatorSystemPlanController(CreatorSystemPlanService service) { this.service = service; }

  @GetMapping
  @Operation(summary = "Xem các gói CC đang mở bán")
  public List<CreatorSystemPlanView> list() { return service.available(); }

  @GetMapping("/me")
  @Operation(summary = "Xem gói và quyền lợi hiện tại của CC")
  public CreatorSystemSubscriptionView current(@AuthenticationPrincipal Jwt jwt) {
    return service.current(id(jwt));
  }

  @PostMapping("/{planId}/subscribe")
  @ResponseStatus(HttpStatus.ACCEPTED)
  @Operation(summary = "Tạo checkout SePay cho gói CC; chỉ kích hoạt sau khi nhận xác nhận thanh toán")
  public CheckoutPaymentView subscribe(@AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID planId) {
    return service.subscribe(id(jwt), planId);
  }

  @DeleteMapping("/me/pending-checkout")
  @Operation(summary = "Hủy checkout gói CC đang chờ để có thể tạo checkout mới; không hoàn tiền")
  public CheckoutPaymentView cancelPendingCheckout(@AuthenticationPrincipal Jwt jwt) {
    return service.cancelPendingCheckout(id(jwt));
  }

  private UUID id(Jwt jwt) { return UUID.fromString(jwt.getClaimAsString("user_id")); }
}
