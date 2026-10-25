package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.response.PodcastTranscriptView;
import com.prmteam7.podcasthistory.service.PodcastTranscriptService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Podcast transcripts")
public class PodcastTranscriptController {
    private final PodcastTranscriptService transcripts;

    public PodcastTranscriptController(PodcastTranscriptService transcripts) {
        this.transcripts = transcripts;
    }

    @GetMapping("/api/podcast-transcripts/{podcastId}")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "Creator xem transcript của podcast thuộc kênh; Listener xem khi có quyền nghe")
    public PodcastTranscriptView transcript(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId) {
        return transcripts.currentForViewer(userId(jwt), podcastId);
    }

    private UUID userId(Jwt jwt) {
        return UUID.fromString(jwt.getClaimAsString("user_id"));
    }
}
