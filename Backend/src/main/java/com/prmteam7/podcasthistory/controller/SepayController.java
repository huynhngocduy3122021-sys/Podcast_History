package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.SepayCreateRequest;
import com.prmteam7.podcasthistory.dto.request.SepayWebhookRequest;
import com.prmteam7.podcasthistory.dto.response.SepayCreateResponse;
import com.prmteam7.podcasthistory.dto.response.SepayPaymentStatusResponse;
import com.prmteam7.podcasthistory.service.SepayService;
import jakarta.validation.Valid;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping("/api/payments/sepay")
public class SepayController {
  private final SepayService sepayService;

  public SepayController(SepayService sepayService) {
    this.sepayService = sepayService;
  }

  @PostMapping("/create")
  public ResponseEntity<SepayCreateResponse> createPayment(
      @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody SepayCreateRequest request) {
    UUID userId = UUID.fromString(jwt.getClaimAsString("user_id"));
    return ResponseEntity.ok(sepayService.createPayment(userId, request.paymentId()));
  }

  @GetMapping("/{paymentId}/status")
  public ResponseEntity<SepayPaymentStatusResponse> getPaymentStatus(
      @AuthenticationPrincipal Jwt jwt, @PathVariable UUID paymentId) {
    UUID userId = UUID.fromString(jwt.getClaimAsString("user_id"));
    return ResponseEntity.ok(sepayService.getPaymentStatus(userId, paymentId));
  }

  @PostMapping("/webhook")
  public ResponseEntity<Map<String, Boolean>> webhook(
      @RequestHeader(value = HttpHeaders.AUTHORIZATION, required = false) String authorization,
      @RequestBody(required = false) SepayWebhookRequest request) {
    if (!sepayService.isAuthorized(authorization)) {
      return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("success", false));
    }
    sepayService.processWebhook(request);
    return ResponseEntity.ok(Map.of("success", true));
  }
}
