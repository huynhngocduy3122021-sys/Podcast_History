package com.prmteam7.podcasthistory.controller;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.prmteam7.podcasthistory.dto.request.WithdrawalRequestInput;
import com.prmteam7.podcasthistory.dto.response.PayoutAccountResponse;
import com.prmteam7.podcasthistory.dto.response.ReleaseFundsResponse;
import com.prmteam7.podcasthistory.dto.response.WalletBalanceResponse;
import com.prmteam7.podcasthistory.dto.response.WithdrawalResponse;
import com.prmteam7.podcasthistory.service.CreatorWalletService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/creator/wallet")
@Tag(name = "Creator - wallet and payouts")
@SecurityRequirement(name = "bearerAuth")
public class CreatorWalletController {

    private final CreatorWalletService walletService;

    public CreatorWalletController(CreatorWalletService walletService) {
        this.walletService = walletService;
    }

    @PostMapping("/release-funds")
    @Operation(summary = "Giải ngân các milestone đã duyệt và Payment đã PAID vào số dư khả dụng")
    public ReleaseFundsResponse releaseFunds(@AuthenticationPrincipal Jwt jwt) {
        return walletService.releaseFunds(userId(jwt));
    }

    @GetMapping("/balance")
    @Operation(summary = "Xem số dư khả dụng và số dư đang giữ")
    public WalletBalanceResponse getBalance(@AuthenticationPrincipal Jwt jwt) {
        return walletService.getBalance(userId(jwt));
    }

    @GetMapping("/payout-accounts")
    @Operation(summary = "Xem các tài khoản nhận tiền đang hoạt động")
    public List<PayoutAccountResponse> getPayoutAccounts(@AuthenticationPrincipal Jwt jwt) {
        return walletService.getPayoutAccounts(userId(jwt));
    }

    @PostMapping("/withdrawals")
    @Operation(summary = "Gửi yêu cầu rút tiền và giữ số dư cho đến khi xử lý xong")
    public ResponseEntity<WithdrawalResponse> requestWithdrawal(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody WithdrawalRequestInput request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(walletService.requestWithdrawal(userId(jwt), request));
    }

    @GetMapping("/withdrawals")
    @Operation(summary = "Xem lịch sử yêu cầu rút tiền")
    public List<WithdrawalResponse> getWithdrawalHistory(@AuthenticationPrincipal Jwt jwt) {
        return walletService.getWithdrawalHistory(userId(jwt));
    }

    private UUID userId(Jwt jwt) {
        return UUID.fromString(jwt.getClaimAsString("user_id"));
    }
}
