package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.ApproveCreatorApplicationRequest;
import com.prmteam7.podcasthistory.dto.request.RejectCreatorApplicationRequest;
import com.prmteam7.podcasthistory.dto.response.CreatorApplicationResponse;
import com.prmteam7.podcasthistory.service.CreatorApplicationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/creator-applications")
@Tag(name = "Admin - creator applications", description = "Admin duyệt hồ sơ Creator")
@SecurityRequirement(name = "bearerAuth")
public class AdminCreatorApplicationController {

  private final CreatorApplicationService creatorApplicationService;

  public AdminCreatorApplicationController(CreatorApplicationService creatorApplicationService) {
    this.creatorApplicationService = creatorApplicationService;
  }

  @GetMapping("/pending")
  @Operation(summary = "Xem danh sách hồ sơ Creator đang chờ duyệt")
  public List<CreatorApplicationResponse> getPendingApplications() {
    return creatorApplicationService.getPendingApplications();
  }

  @GetMapping
  @io.swagger.v3.oas.annotations.Operation(
      summary = "Toàn bộ hồ sơ Creator theo trạng thái, phân trang")
  public org.springframework.data.domain.Page<
          com.prmteam7.podcasthistory.dto.response.CreatorApplicationResponse>
      history(
          @AuthenticationPrincipal Jwt jwt,
          @org.springframework.web.bind.annotation.RequestParam(required = false) String status,
          @org.springframework.web.bind.annotation.RequestParam(defaultValue = "0") int page,
          @org.springframework.web.bind.annotation.RequestParam(defaultValue = "20") int size) {
    return creatorApplicationService.history(
        java.util.UUID.fromString(jwt.getClaimAsString("user_id")), status, page, size);
  }

  @GetMapping("/{applicationId}")
  @io.swagger.v3.oas.annotations.Operation(summary = "Chi tiết hồ sơ đăng ký Creator")
  public com.prmteam7.podcasthistory.dto.response.CreatorApplicationResponse detail(
      @AuthenticationPrincipal Jwt jwt, @PathVariable UUID applicationId) {
    return creatorApplicationService.detail(
        java.util.UUID.fromString(jwt.getClaimAsString("user_id")), applicationId);
  }

  @PostMapping("/{applicationId}/approve")
  @Operation(summary = "Duyệt hồ sơ Creator và chuyển vai trò User thành CREATOR")
  public CreatorApplicationResponse approve(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID applicationId,
      @Valid @RequestBody(required = false) ApproveCreatorApplicationRequest request) {
    String note = request == null ? null : request.note();
    return creatorApplicationService.approve(userId(jwt), applicationId, note);
  }

  @PostMapping("/{applicationId}/reject")
  @Operation(summary = "Từ chối hồ sơ Creator đang có verification_status=PENDING")
  public CreatorApplicationResponse reject(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID applicationId,
      @Valid @RequestBody RejectCreatorApplicationRequest request) {
    return creatorApplicationService.reject(userId(jwt), applicationId, request.note());
  }

  private UUID userId(Jwt jwt) {
    return UUID.fromString(jwt.getClaimAsString("user_id"));
  }
}
