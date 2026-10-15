package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.AdminRequests.*;
import com.prmteam7.podcasthistory.dto.response.AdminResponses.PlanItem;
import com.prmteam7.podcasthistory.service.AdminMembershipPlanService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/admin/membership-plans")
@Tag(name = "Admin - channel membership plans")
@SecurityRequirement(name = "bearerAuth")
public class AdminMembershipPlanController {
  private final AdminMembershipPlanService service;

  public AdminMembershipPlanController(AdminMembershipPlanService service) {
    this.service = service;
  }

  @GetMapping
  @Operation(summary = "Danh sách gói, lọc kênh/trạng thái, phân trang")
  public Page<PlanItem> list(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(required = false) UUID creatorId,
      @RequestParam(required = false) String status,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return service.list(id(jwt), creatorId, status, page, size);
  }

  @GetMapping("/{planId}")
  @Operation(summary = "Chi tiết gói thành viên kênh")
  public PlanItem get(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID planId) {
    return service.get(id(jwt), planId);
  }

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  @Operation(summary = "Admin tạo gói cho kênh được duyệt")
  public PlanItem create(
      @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody MembershipPlanWrite body) {
    return service.create(id(jwt), body);
  }

  @PutMapping("/{planId}")
  @Operation(summary = "Sửa gói; giữ nguyên giá/thời hạn nếu gói đã có subscription")
  public PlanItem update(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID planId,
      @Valid @RequestBody MembershipPlanWrite body) {
    return service.update(id(jwt), planId, body);
  }

  @DeleteMapping("/{planId}")
  @Operation(summary = "Tắt gói, giữ subscription và lịch sử thanh toán")
  public PlanItem delete(
      @AuthenticationPrincipal Jwt jwt, @PathVariable UUID planId, @Valid @RequestBody Note body) {
    return service.deactivate(id(jwt), planId, body.note());
  }

  private UUID id(Jwt jwt) {
    return UUID.fromString(jwt.getClaimAsString("user_id"));
  }
}
