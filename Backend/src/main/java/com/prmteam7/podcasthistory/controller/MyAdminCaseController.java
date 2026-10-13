package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.AdminRequests.Note;
import com.prmteam7.podcasthistory.dto.response.AdminResponses.*;
import com.prmteam7.podcasthistory.service.*;
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
@RequestMapping("/api")
@Tag(name = "User - notifications and disputes")
@SecurityRequirement(name = "bearerAuth")
public class MyAdminCaseController {
  private final AdminDisputeService disputes;
  private final UserNotificationService notifications;

  public MyAdminCaseController(
      AdminDisputeService disputes, UserNotificationService notifications) {
    this.disputes = disputes;
    this.notifications = notifications;
  }

  @PostMapping("/contracts/{contractId}/disputes")
  @ResponseStatus(HttpStatus.CREATED)
  @Operation(summary = "Bên tham gia hợp đồng gửi tranh chấp cho Admin")
  public DisputeItem open(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID contractId,
      @Valid @RequestBody Note body) {
    return disputes.open(id(jwt), contractId, body.note());
  }

  @GetMapping("/me/disputes")
  @Operation(summary = "Các tranh chấp của hợp đồng mình tham gia")
  public Page<DisputeItem> mine(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return disputes.mine(id(jwt), page, size);
  }

  @GetMapping("/me/notifications")
  @Operation(summary = "Thông báo xét duyệt, report, thanh toán và tranh chấp")
  public Page<NotificationItem> notifications(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return notifications.list(id(jwt), page, size);
  }

  @PutMapping("/me/notifications/{notificationId}/read")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(summary = "Đánh dấu thông báo của mình đã đọc")
  public void read(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID notificationId) {
    notifications.read(id(jwt), notificationId);
  }

  private UUID id(Jwt jwt) {
    return UUID.fromString(jwt.getClaimAsString("user_id"));
  }
}
