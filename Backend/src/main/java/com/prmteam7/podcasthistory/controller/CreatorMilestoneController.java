package com.prmteam7.podcasthistory.controller;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.prmteam7.podcasthistory.dto.response.MilestoneSubmissionResponse;
import com.prmteam7.podcasthistory.service.PodcastRequestService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/creator/milestones")
@Tag(name = "Creator - milestones")
@SecurityRequirement(name = "bearerAuth")
public class CreatorMilestoneController {

    private final PodcastRequestService podcastRequestService;

    public CreatorMilestoneController(PodcastRequestService podcastRequestService) {
        this.podcastRequestService = podcastRequestService;
    }

    @PostMapping(path = "/{milestoneId}/submissions", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Nộp sản phẩm của hợp đồng cũ; hợp đồng giữ tiền dùng API drafts và deliver sau khi AI duyệt")
    public ResponseEntity<MilestoneSubmissionResponse> submit(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID milestoneId,
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "note", required = false) String note) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(podcastRequestService.submitMilestone(userId(jwt), milestoneId, file, note));
    }

    private UUID userId(Jwt jwt) {
        return UUID.fromString(jwt.getClaimAsString("user_id"));
    }
}
