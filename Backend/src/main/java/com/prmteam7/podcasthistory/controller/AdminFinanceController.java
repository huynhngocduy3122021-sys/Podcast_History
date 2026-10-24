package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.AdminRequests.*;
import com.prmteam7.podcasthistory.dto.response.AdminResponses.*;
import com.prmteam7.podcasthistory.service.AdminFinanceService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/admin")
@Tag(name = "Admin - finance and withdrawals")
@SecurityRequirement(name = "bearerAuth")
public class AdminFinanceController {
  private final AdminFinanceService service;

  public AdminFinanceController(AdminFinanceService service) {
    this.service = service;
  }

  @GetMapping("/withdrawals")
  @Operation(summary = "Danh sách yêu cầu rút tiền, phân trang")
  public Page<WithdrawalItem> withdrawals(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(required = false) String status,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return service.withdrawals(id(jwt), status, page, size);
  }

  @GetMapping("/withdrawals/{withdrawalId}")
  @Operation(summary = "Chi tiết yêu cầu rút tiền")
  public WithdrawalItem withdrawal(
      @AuthenticationPrincipal Jwt jwt, @PathVariable UUID withdrawalId) {
    return service.withdrawal(id(jwt), withdrawalId);
  }

  @GetMapping("/withdrawals/{withdrawalId}/reviews")
  @Operation(summary = "Lịch sử duyệt và kết quả chuyển tiền")
  public Page<WithdrawalReviewItem> history(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID withdrawalId,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return service.withdrawalReviews(id(jwt), withdrawalId, page, size);
  }

  @PostMapping("/withdrawals/{withdrawalId}/approve")
  @Operation(summary = "Duyệt và giữ tiền trong ví; chưa chuyển tiền ngoài hệ thống")
  public WithdrawalItem approve(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID withdrawalId,
      @Valid @RequestBody ApproveWithdrawal body) {
    return service.approve(id(jwt), withdrawalId, body);
  }

  @PostMapping("/withdrawals/{withdrawalId}/reject")
  @Operation(summary = "Từ chối yêu cầu PENDING, không thay đổi số dư")
  public WithdrawalItem reject(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID withdrawalId,
      @Valid @RequestBody Note body) {
    return service.reject(id(jwt), withdrawalId, body.note());
  }

  @PostMapping("/withdrawals/{withdrawalId}/complete")
  @Operation(summary = "Ghi nhận chuyển khoản thủ công đã thành công; yêu cầu mã chuyển khoản")
  public WithdrawalItem complete(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID withdrawalId,
      @Valid @RequestBody CompleteWithdrawal body) {
    return service.complete(id(jwt), withdrawalId, body);
  }

  @PostMapping("/withdrawals/{withdrawalId}/fail")
  @Operation(summary = "Ghi nhận chuyển tiền thất bại và hoàn tiền đang giữ về ví")
  public WithdrawalItem fail(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID withdrawalId,
      @Valid @RequestBody Note body) {
    return service.fail(id(jwt), withdrawalId, body.note());
  }

  @GetMapping("/wallets")
  @Operation(summary = "Xem ví và số dư khả dụng, phân trang")
  public Page<WalletItem> wallets(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return service.wallets(id(jwt), page, size);
  }

  @GetMapping("/wallet-transactions")
  @Operation(summary = "Xem giao dịch ví; lọc walletId/status")
  public Page<TransactionItem> transactions(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(required = false) UUID walletId,
      @RequestParam(required = false) String status,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return service.transactions(id(jwt), walletId, status, page, size);
  }

  @GetMapping("/payments")
  @Operation(summary = "Danh sách thanh toán, lọc trạng thái, phân trang")
  public Page<PaymentItem> payments(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(required = false) String status,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return service.payments(id(jwt), status, page, size);
  }

  @GetMapping("/payments/{paymentId}")
  @Operation(summary = "Chi tiết thanh toán")
  public PaymentItem payment(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID paymentId) {
    return service.payment(id(jwt), paymentId);
  }

  @PostMapping("/payments/{paymentId}/reconcile")
  @Operation(summary = "Admin đối soát chuyển khoản thủ công; PAID có thể kích hoạt membership")
  public PaymentItem reconcile(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID paymentId,
      @Valid @RequestBody ReconcilePayment body) {
    return service.reconcile(id(jwt), paymentId, body);
  }

  @PostMapping("/payments/{paymentId}/refund")
  @Operation(summary = "Ghi nhận hoàn toàn bộ tiền đã chuyển trả thủ công; không gọi ngân hàng")
  public PaymentItem refund(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID paymentId,
      @Valid @RequestBody RefundPayment body) {
    return service.refund(id(jwt), paymentId, body);
  }

  private UUID id(Jwt jwt) {
    return UUID.fromString(jwt.getClaimAsString("user_id"));
  }
}
