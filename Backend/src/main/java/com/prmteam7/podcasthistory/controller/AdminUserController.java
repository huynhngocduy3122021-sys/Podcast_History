package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.AdminRequests.*;
import com.prmteam7.podcasthistory.dto.response.AdminResponses.*;
import com.prmteam7.podcasthistory.enums.UserRole;
import com.prmteam7.podcasthistory.service.AdminUserService;
import io.swagger.v3.oas.annotations.*;
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
@RequestMapping("/api/admin")
@Tag(name = "Admin - users and staff")
@SecurityRequirement(name = "bearerAuth")
public class AdminUserController {
  private final AdminUserService service;

  public AdminUserController(AdminUserService service) {
    this.service = service;
  }

  @GetMapping("/users")
  @Operation(summary = "Tìm, lọc và phân trang người dùng")
  public Page<UserItem> list(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(required = false) String q,
      @RequestParam(required = false) UserRole role,
      @RequestParam(required = false) Boolean active,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return service.list(id(jwt), q, role, active, page, size);
  }

  @GetMapping("/users/{userId}")
  @Operation(summary = "Chi tiết user, không trả password/token")
  public UserItem detail(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID userId) {
    return service.detail(id(jwt), userId);
  }

  @PatchMapping("/users/{userId}")
  @Operation(summary = "Cập nhật hồ sơ user")
  public UserItem update(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID userId,
      @Valid @RequestBody UserProfile body) {
    return service.update(id(jwt), userId, body);
  }

  @PatchMapping("/users/{userId}/access")
  @Operation(summary = "Khóa/mở khóa và thu hồi toàn bộ phiên cũ")
  public UserItem access(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID userId,
      @Valid @RequestBody UserAccess body) {
    return service.access(id(jwt), userId, body);
  }

  @PatchMapping("/users/{userId}/verification")
  @Operation(summary = "Duyệt/xác minh tài khoản user")
  public UserItem verify(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID userId,
      @Valid @RequestBody UserVerification body) {
    return service.verify(id(jwt), userId, body);
  }

  @PatchMapping("/users/{userId}/role")
  @Operation(summary = "Đổi role Listener/Creator/Staff; Creator cần hồ sơ APPROVED")
  public UserItem role(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID userId,
      @Valid @RequestBody UserRoleChange body) {
    return service.role(id(jwt), userId, body);
  }

  @PostMapping("/users/{userId}/revoke-sessions")
  @Operation(summary = "Thu hồi access và refresh token của user")
  public UserItem revoke(
      @AuthenticationPrincipal Jwt jwt, @PathVariable UUID userId, @Valid @RequestBody Note body) {
    return service.revokeSessions(id(jwt), userId, body.note());
  }

  @GetMapping("/staff")
  @Operation(summary = "Danh sách tài khoản Staff")
  public Page<UserItem> staff(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return service.list(id(jwt), null, UserRole.STAFF, null, page, size);
  }

  @PostMapping("/staff")
  @ResponseStatus(HttpStatus.CREATED)
  @Operation(summary = "Admin tạo tài khoản Staff, password được băm")
  public UserItem createStaff(
      @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody StaffCreate body) {
    return service.createStaff(id(jwt), body);
  }

  @GetMapping("/audit-logs")
  @Operation(summary = "Lịch sử hành động quản trị")
  public Page<AuditItem> audits(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(required = false) String resourceType,
      @RequestParam(required = false) UUID resourceId,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return service.auditLog(id(jwt), resourceType, resourceId, page, size);
  }

  private UUID id(Jwt jwt) {
    return UUID.fromString(jwt.getClaimAsString("user_id"));
  }
}
