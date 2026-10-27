package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.response.LivestreamResponses.AgoraJoin;
import com.prmteam7.podcasthistory.dto.response.LivestreamResponses.ChatJoin;
import com.prmteam7.podcasthistory.dto.response.LivestreamResponses.Item;
import com.prmteam7.podcasthistory.service.LivestreamService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/livestreams")
@Tag(name = "Listener - livestreams", description = "Khám phá và xem livestream qua Agora")
@SecurityRequirement(name = "bearerAuth")
public class LivestreamController {
  private final LivestreamService service;

  public LivestreamController(LivestreamService service) {
    this.service = service;
  }

  @GetMapping
  @Operation(summary = "Danh sách livestream đang phát")
  public Page<Item> live(@RequestParam(defaultValue = "0") int page,
      @RequestParam(defaultValue = "20") int size) {
    return service.live(page, size);
  }

  @GetMapping("/{livestreamId}")
  public Item detail(@PathVariable UUID livestreamId) {
    return service.visible(livestreamId);
  }

  @PostMapping("/{livestreamId}/join")
  @Operation(summary = "Listener lấy Agora token quyền audience")
  public AgoraJoin join(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID livestreamId) {
    return service.join(UUID.fromString(jwt.getClaimAsString("user_id")), livestreamId);
  }

  @PostMapping("/{livestreamId}/chat-token")
  @Operation(summary = "Listener lấy Agora Signaling token để chat trong livestream")
  public ChatJoin chatToken(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID livestreamId) {
    return service.listenerChatToken(UUID.fromString(jwt.getClaimAsString("user_id")), livestreamId);
  }
}
