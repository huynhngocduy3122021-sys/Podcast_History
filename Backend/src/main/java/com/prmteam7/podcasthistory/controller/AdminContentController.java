package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.AdminRequests.*;
import com.prmteam7.podcasthistory.dto.response.AdminResponses.*;
import com.prmteam7.podcasthistory.service.AdminContentService;
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
@RequestMapping("/api/admin")
@Tag(name = "Admin - reports and appeals", description = "Admin và Staff cùng xử lý báo cáo, nội dung và khiếu nại")
@SecurityRequirement(name = "bearerAuth")
public class AdminContentController {
  private final AdminContentService service;

  public AdminContentController(AdminContentService service) {
    this.service = service;
  }

  @GetMapping("/reports")
  @Operation(summary = "Danh sách report phân trang")
  public Page<ReportItem> reports(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(required = false) String status,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return service.listReports(id(jwt), status, page, size);
  }

  @GetMapping("/reports/{reportId}")
  @Operation(summary = "Chi tiết report và quyết định xử lý")
  public ReportItem report(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID reportId) {
    return service.report(id(jwt), reportId);
  }

  @PostMapping("/reports/{reportId}/claim")
  @Operation(summary = "Nhận xử lý report; Admin được nhận lại report")
  public ReportItem claim(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID reportId) {
    return service.claim(id(jwt), reportId);
  }

  @PostMapping("/reports/{reportId}/resolve")
  @Operation(summary = "DISMISS, HIDE_CONTENT hoặc DELETE_CONTENT")
  public ReportItem resolve(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID reportId,
      @Valid @RequestBody ResolveReport body) {
    return service.resolve(id(jwt), reportId, body);
  }

  @PostMapping("/podcasts/{podcastId}/hide")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(summary = "Ẩn podcast và thông báo chủ kênh")
  public void hide(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID podcastId,
      @Valid @RequestBody Note body) {
    service.moderate(id(jwt), podcastId, "HIDE", body.note());
  }

  @DeleteMapping("/podcasts/{podcastId}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(summary = "Xóa mềm podcast, lưu lịch sử và lý do")
  public void delete(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID podcastId,
      @Valid @RequestBody Note body) {
    service.moderate(id(jwt), podcastId, "DELETE", body.note());
  }

  @PostMapping("/podcasts/{podcastId}/restore")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(summary = "Chuyển podcast HIDDEN về PENDING_REVIEW")
  public void restore(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID podcastId,
      @Valid @RequestBody Note body) {
    service.moderate(id(jwt), podcastId, "RESTORE", body.note());
  }

  @GetMapping("/podcast-appeals")
  @Operation(summary = "Danh sách khiếu nại của Creator")
  public Page<AppealItem> appeals(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(required = false) String status,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return service.listAppeals(id(jwt), status, page, size);
  }

  @GetMapping("/podcast-appeals/{appealId}")
  @Operation(summary = "Chi tiết khiếu nại")
  public AppealItem appeal(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID appealId) {
    return service.appeal(id(jwt), appealId);
  }

  @PostMapping("/podcast-appeals/{appealId}/resolve")
  @Operation(summary = "ACCEPT chuyển về hàng đợi duyệt; REJECT giữ quyết định cũ")
  public AppealItem resolveAppeal(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID appealId,
      @Valid @RequestBody ResolveAppeal body) {
    return service.resolveAppeal(id(jwt), appealId, body);
  }

  private UUID id(Jwt jwt) {
    return UUID.fromString(jwt.getClaimAsString("user_id"));
  }
}
