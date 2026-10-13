package com.prmteam7.podcasthistory.controller;

import java.util.List;
import java.util.UUID;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.prmteam7.podcasthistory.dto.request.AcceptSeriesRequest;
import com.prmteam7.podcasthistory.dto.request.RejectSeriesRequest;
import com.prmteam7.podcasthistory.dto.response.SeriesRequestDecisionResponse;
import com.prmteam7.podcasthistory.dto.response.SeriesRequestResponse;
import com.prmteam7.podcasthistory.service.PodcastRequestService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/creator/requests")
@Tag(name = "Creator - podcast requests")
@SecurityRequirement(name = "bearerAuth")
public class CreatorRequestController {

    private final PodcastRequestService podcastRequestService;

    public CreatorRequestController(PodcastRequestService podcastRequestService) {
        this.podcastRequestService = podcastRequestService;
    }

    @GetMapping("/incoming")
    @Operation(summary = "Creator xem các yêu cầu đang chờ")
    public List<SeriesRequestResponse> getIncoming(@AuthenticationPrincipal Jwt jwt) {
        return podcastRequestService.getCreatorInbox(userId(jwt));
    }

    @PostMapping("/{requestId}/accept")
    @Operation(summary = "Creator chấp nhận yêu cầu và báo giá theo các mốc")
    public SeriesRequestDecisionResponse accept(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID requestId,
            @Valid @RequestBody AcceptSeriesRequest request) {
        return podcastRequestService.acceptRequest(userId(jwt), requestId, request);
    }

    @PostMapping("/{requestId}/reject")
    @Operation(summary = "Creator từ chối yêu cầu")
    public SeriesRequestDecisionResponse reject(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID requestId,
            @Valid @RequestBody RejectSeriesRequest request) {
        return podcastRequestService.rejectRequest(userId(jwt), requestId, request);
    }

    private UUID userId(Jwt jwt) {
        return UUID.fromString(jwt.getClaimAsString("user_id"));
    }
}
