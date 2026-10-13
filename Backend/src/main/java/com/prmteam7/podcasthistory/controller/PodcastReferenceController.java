package com.prmteam7.podcasthistory.controller;

import java.util.List;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import com.prmteam7.podcasthistory.dto.response.PodcastReferenceResponse;
import com.prmteam7.podcasthistory.dto.response.ReferenceFileResponse;
import com.prmteam7.podcasthistory.service.PodcastReferenceService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/podcasts/{podcastId}/references")
@Tag(name = "Podcast sources")
@SecurityRequirement(name = "bearerAuth")
public class PodcastReferenceController {
    private final PodcastReferenceService service;

    public PodcastReferenceController(PodcastReferenceService service) {
        this.service = service;
    }

    @GetMapping
    @Operation(summary = "Xem nguồn của podcast đã duyệt; nội dung độc quyền cần quyền thành viên")
    public List<PodcastReferenceResponse> list(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID podcastId) {
        return service.listForListener(UUID.fromString(jwt.getClaimAsString("user_id")), podcastId);
    }

    @GetMapping("/{referenceId}/file")
    @Operation(summary = "Lấy URL PDF của podcast đã duyệt sau khi kiểm tra quyền truy cập")
    public ReferenceFileResponse download(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId, @PathVariable UUID referenceId) {
        return service.downloadForListener(UUID.fromString(jwt.getClaimAsString("user_id")), podcastId, referenceId);
    }
}
