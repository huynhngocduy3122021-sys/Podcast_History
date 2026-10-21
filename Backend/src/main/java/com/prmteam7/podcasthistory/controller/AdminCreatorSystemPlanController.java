package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.CreatorSystemPlanWrite;
import com.prmteam7.podcasthistory.dto.response.CreatorSystemPlanView;
import com.prmteam7.podcasthistory.service.CreatorSystemPlanService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/admin/creator-system-plans")
@Tag(name = "Admin - Creator system plans")
@SecurityRequirement(name = "bearerAuth")
public class AdminCreatorSystemPlanController {
  private final CreatorSystemPlanService service;

  public AdminCreatorSystemPlanController(CreatorSystemPlanService service) { this.service = service; }

  @GetMapping
  @Operation(summary = "Danh sách gói CC dùng chung toàn hệ thống")
  public List<CreatorSystemPlanView> list(@AuthenticationPrincipal Jwt jwt) {
    return service.adminList(id(jwt));
  }

  @GetMapping("/{planId}")
  public CreatorSystemPlanView get(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID planId) {
    return service.adminGet(id(jwt), planId);
  }

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  @Operation(summary = "Tạo gói CC và tự thêm danh sách quyền lợi")
  public CreatorSystemPlanView create(@AuthenticationPrincipal Jwt jwt,
      @Valid @RequestBody CreatorSystemPlanWrite body) {
    return service.create(id(jwt), body);
  }

  @PutMapping("/{planId}")
  @Operation(summary = "Sửa gói CC và quyền lợi; quyền lợi đã mua được giữ nguyên")
  public CreatorSystemPlanView update(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID planId,
      @Valid @RequestBody CreatorSystemPlanWrite body) {
    return service.update(id(jwt), planId, body);
  }

  @DeleteMapping("/{planId}")
  @Operation(summary = "Ngừng bán gói CC; giữ lịch sử đăng ký")
  public CreatorSystemPlanView delete(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID planId) {
    return service.delete(id(jwt), planId);
  }

  private UUID id(Jwt jwt) { return UUID.fromString(jwt.getClaimAsString("user_id")); }
}
