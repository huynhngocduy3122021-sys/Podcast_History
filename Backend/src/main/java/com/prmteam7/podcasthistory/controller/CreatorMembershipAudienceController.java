package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.service.CreatorMembershipAudienceService;
import com.prmteam7.podcasthistory.service.CreatorMembershipAudienceService.MemberItem;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/creator/memberships")
@Tag(name = "Content Creator - channel members")
@SecurityRequirement(name = "bearerAuth")
public class CreatorMembershipAudienceController {
  private final CreatorMembershipAudienceService service;

  public CreatorMembershipAudienceController(CreatorMembershipAudienceService service) {
    this.service = service;
  }

  @GetMapping
  @Operation(summary = "Xem Listener đăng ký membership của chính kênh CC")
  public Page<MemberItem> list(@AuthenticationPrincipal Jwt jwt,
      @RequestParam(defaultValue = "ACTIVE") String status,
      @RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return service.list(UUID.fromString(jwt.getClaimAsString("user_id")), status, page, size);
  }
}
