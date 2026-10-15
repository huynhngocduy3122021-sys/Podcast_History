package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.AdminRequests.*;
import com.prmteam7.podcasthistory.dto.response.AdminResponses.*;
import com.prmteam7.podcasthistory.service.AdminDisputeService;
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
@Tag(name = "Admin - contracts and disputes")
@SecurityRequirement(name = "bearerAuth")
public class AdminDisputeController {
  private final AdminDisputeService service;

  public AdminDisputeController(AdminDisputeService service) {
    this.service = service;
  }

  @GetMapping("/contracts")
  @Operation(summary = "Danh sách hợp đồng phân trang")
  public Page<ContractItem> contracts(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(required = false) String status,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return service.contracts(id(jwt), status, page, size);
  }

  @GetMapping("/contracts/{contractId}")
  @Operation(summary = "Chi tiết hợp đồng và các mốc")
  public ContractItem contract(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID contractId) {
    return service.contract(id(jwt), contractId);
  }

  @PostMapping("/contracts/{contractId}/disputes")
  @ResponseStatus(HttpStatus.CREATED)
  @Operation(summary = "Admin mở hồ sơ tranh chấp của hợp đồng")
  public DisputeItem open(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID contractId,
      @Valid @RequestBody Note body) {
    return service.open(id(jwt), contractId, body.note());
  }

  @GetMapping("/disputes")
  @Operation(summary = "Danh sách tranh chấp cần xử lý")
  public Page<DisputeItem> disputes(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(required = false) String status,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return service.disputes(id(jwt), status, page, size);
  }

  @GetMapping("/disputes/{disputeId}")
  @Operation(summary = "Chi tiết tranh chấp")
  public DisputeItem dispute(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID disputeId) {
    return service.dispute(id(jwt), disputeId);
  }

  @PostMapping("/disputes/{disputeId}/resolve")
  @Operation(summary = "Kết luận tiếp tục/hủy/kết thúc; không tự chuyển hay hoàn tiền")
  public DisputeItem resolve(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID disputeId,
      @Valid @RequestBody ResolveDispute body) {
    return service.resolve(id(jwt), disputeId, body);
  }

  private UUID id(Jwt jwt) {
    return UUID.fromString(jwt.getClaimAsString("user_id"));
  }
}
