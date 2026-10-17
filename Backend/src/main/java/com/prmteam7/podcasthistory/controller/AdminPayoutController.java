package com.prmteam7.podcasthistory.controller;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.prmteam7.podcasthistory.dto.request.RecordPayoutResultRequest;
import com.prmteam7.podcasthistory.dto.request.RegisterVerifiedPayoutAccountRequest;
import com.prmteam7.podcasthistory.dto.response.AdminWithdrawalResponse;
import com.prmteam7.podcasthistory.dto.response.PayoutAccountResponse;
import com.prmteam7.podcasthistory.dto.response.WithdrawalResponse;
import com.prmteam7.podcasthistory.service.CreatorWalletService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/admin/payouts")
@Tag(name = "Admin - creator payouts")
@SecurityRequirement(name = "bearerAuth")
public class AdminPayoutController {

    private final CreatorWalletService walletService;

    public AdminPayoutController(CreatorWalletService walletService) {
        this.walletService = walletService;
    }

    @PostMapping("/creators/{creatorProfileId}/accounts")
    @Operation(summary = "Đăng ký tài khoản nhận tiền đã được xác minh bởi payout provider")
    public ResponseEntity<PayoutAccountResponse> registerVerifiedAccount(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID creatorProfileId,
            @Valid @RequestBody RegisterVerifiedPayoutAccountRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(walletService.registerVerifiedPayoutAccount(
                        userId(jwt), creatorProfileId, request));
    }

    @GetMapping("/withdrawals/pending")
    @Operation(summary = "Xem yêu cầu rút tiền đang chờ và thông tin payout chỉ dành cho Admin")
    public List<AdminWithdrawalResponse> getPendingWithdrawals(
            @AuthenticationPrincipal Jwt jwt) {
        return walletService.getPendingWithdrawals(userId(jwt));
    }

    @PostMapping("/withdrawals/{withdrawalId}/result")
    @Operation(summary = "Ghi nhận kết quả chuyển tiền; FAILED sẽ hoàn tiền đang giữ về số dư khả dụng")
    public WithdrawalResponse recordResult(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID withdrawalId,
            @Valid @RequestBody RecordPayoutResultRequest request) {
        return walletService.recordPayoutResult(userId(jwt), withdrawalId, request);
    }

    private UUID userId(Jwt jwt) {
        return UUID.fromString(jwt.getClaimAsString("user_id"));
    }
}
