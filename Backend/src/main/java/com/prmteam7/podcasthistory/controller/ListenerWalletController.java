package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.response.CheckoutPaymentView;
import com.prmteam7.podcasthistory.model.UserWallet;
import com.prmteam7.podcasthistory.service.ListenerWalletService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/listener/wallet")
public class ListenerWalletController {
  private final ListenerWalletService service;

  public ListenerWalletController(ListenerWalletService service) { this.service = service; }

  public record Balance(UUID walletId, BigDecimal availableBalance, BigDecimal heldBalance,
      String currency) {}
  public record TopUpRequest(@NotNull @DecimalMin("10000") @DecimalMax("100000000")
      @Digits(integer = 9, fraction = 0) BigDecimal amount) {}

  @GetMapping
  public Balance balance(@AuthenticationPrincipal Jwt jwt) {
    UserWallet wallet = service.balance(userId(jwt));
    return new Balance(wallet.getUserWalletId(), wallet.getBalance(), wallet.getHeldBalance(),
        wallet.getCurrency());
  }

  @PostMapping("/top-ups")
  @ResponseStatus(HttpStatus.CREATED)
  public CheckoutPaymentView topUp(@AuthenticationPrincipal Jwt jwt,
      @Valid @RequestBody TopUpRequest request) {
    return service.topUp(userId(jwt), request.amount());
  }

  private UUID userId(Jwt jwt) { return UUID.fromString(jwt.getClaimAsString("user_id")); }
}
