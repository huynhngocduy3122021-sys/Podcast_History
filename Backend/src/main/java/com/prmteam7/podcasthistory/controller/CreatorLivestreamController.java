package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.LivestreamRequests.Create;
import com.prmteam7.podcasthistory.dto.response.LivestreamResponses.AgoraJoin;
import com.prmteam7.podcasthistory.dto.response.LivestreamResponses.ChatJoin;
import com.prmteam7.podcasthistory.dto.response.LivestreamResponses.Item;
import com.prmteam7.podcasthistory.service.LivestreamService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/creator/livestreams")
@Tag(name = "Creator - livestreams", description = "Quản lý và phát livestream qua Agora")
@SecurityRequirement(name = "bearerAuth")
public class CreatorLivestreamController {
  private final LivestreamService service;

  public CreatorLivestreamController(LivestreamService service) {
    this.service = service;
  }

  @PostMapping
  @Operation(summary = "Tạo bản nháp livestream")
  public ResponseEntity<Item> create(@AuthenticationPrincipal Jwt jwt,
      @Valid @RequestBody Create request) {
    return ResponseEntity.status(HttpStatus.CREATED).body(service.create(userId(jwt), request));
  }

  @GetMapping
  @Operation(summary = "Danh sách livestream của kênh hiện tại")
  public List<Item> mine(@AuthenticationPrincipal Jwt jwt) {
    return service.mine(userId(jwt));
  }

  @GetMapping("/{livestreamId}")
  public Item own(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID livestreamId) {
    return service.own(userId(jwt), livestreamId);
  }

  @PostMapping("/{livestreamId}/start")
  @Operation(summary = "Bắt đầu phát và lấy Agora token quyền host")
  public AgoraJoin start(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID livestreamId) {
    return service.start(userId(jwt), livestreamId);
  }

  @PostMapping("/{livestreamId}/token")
  @Operation(summary = "Cấp lại token quyền host khi livestream đang phát")
  public AgoraJoin hostToken(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID livestreamId) {
    return service.hostToken(userId(jwt), livestreamId);
  }

  @PostMapping("/{livestreamId}/chat-token")
  @Operation(summary = "Creator lấy Agora Signaling token để chat trong livestream")
  public ChatJoin chatToken(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID livestreamId) {
    return service.hostChatToken(userId(jwt), livestreamId);
  }

  @PostMapping("/{livestreamId}/end")
  @Operation(summary = "Kết thúc livestream")
  public Item end(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID livestreamId) {
    return service.end(userId(jwt), livestreamId);
  }

  private UUID userId(Jwt jwt) {
    return UUID.fromString(jwt.getClaimAsString("user_id"));
  }
}
