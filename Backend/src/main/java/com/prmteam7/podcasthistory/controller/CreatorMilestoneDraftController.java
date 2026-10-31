package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.response.MilestoneDraftResponse;
import com.prmteam7.podcasthistory.dto.response.MilestoneSubmissionResponse;
import com.prmteam7.podcasthistory.service.MilestoneDraftService;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/creator/milestones/{milestoneId}/drafts")
@Tag(name = "Creator - AI reviewed milestone drafts")
@SecurityRequirement(name = "bearerAuth")
public class CreatorMilestoneDraftController {
    private final MilestoneDraftService drafts;
    public CreatorMilestoneDraftController(MilestoneDraftService drafts) { this.drafts = drafts; }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public MilestoneDraftResponse upload(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID milestoneId, @RequestParam("file") MultipartFile file,
            @RequestParam(value = "note", required = false) String note) {
        return drafts.upload(userId(jwt), milestoneId, file, note);
    }

    @GetMapping
    public List<MilestoneDraftResponse> list(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID milestoneId) {
        return drafts.list(userId(jwt), milestoneId);
    }

    @GetMapping("/{draftId}/media")
    public MilestoneDraftService.DraftMediaUrl media(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID milestoneId, @PathVariable UUID draftId) {
        return drafts.media(userId(jwt), milestoneId, draftId);
    }

    @PostMapping("/{draftId}/deliver")
    @ResponseStatus(HttpStatus.CREATED)
    public MilestoneSubmissionResponse deliver(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID milestoneId, @PathVariable UUID draftId) {
        return drafts.deliver(userId(jwt), milestoneId, draftId);
    }

    @PostMapping("/{draftId}/cancel")
    public MilestoneDraftResponse cancel(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID milestoneId, @PathVariable UUID draftId) {
        return drafts.cancel(userId(jwt), milestoneId, draftId);
    }

    private UUID userId(Jwt jwt) { return UUID.fromString(jwt.getClaimAsString("user_id")); }
}
