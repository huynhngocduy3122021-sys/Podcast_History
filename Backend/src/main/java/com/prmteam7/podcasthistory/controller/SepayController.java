package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.SepayWebhookRequest;
import com.prmteam7.podcasthistory.dto.response.PaymentStatusItem;
import com.prmteam7.podcasthistory.dto.response.SepayWebhookResponse;
import com.prmteam7.podcasthistory.service.SepayService;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class SepayController {

  private final SepayService sepayService;

  public SepayController(SepayService sepayService) {
    this.sepayService = sepayService;
  }

  @GetMapping("/me/payments/{paymentId}")
  public PaymentStatusItem getPaymentStatus(
      @AuthenticationPrincipal Jwt jwt, @PathVariable UUID paymentId) {
    return sepayService.getPaymentStatus(userId(jwt), paymentId);
  }

  @PostMapping("/webhooks/sepay")
  public ResponseEntity<SepayWebhookResponse> receiveWebhook(
      @RequestHeader(value = "Authorization", required = false) String authorization,
      @RequestBody(required = false) SepayWebhookRequest request) {
    return sepayService.processWebhook(authorization, request);
  }

  private UUID userId(Jwt jwt) {
    return UUID.fromString(jwt.getClaimAsString("user_id"));
  }
}
