package com.prmteam7.podcasthistory.controller;

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

import com.prmteam7.podcasthistory.dto.request.CreateSeriesRequest;
import com.prmteam7.podcasthistory.dto.request.SendSeriesRequestMessage;
import com.prmteam7.podcasthistory.dto.response.MilestoneResponse;
import com.prmteam7.podcasthistory.dto.response.SeriesRequestMessageResponse;
import com.prmteam7.podcasthistory.dto.response.SeriesRequestResponse;
import com.prmteam7.podcasthistory.service.PodcastRequestService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/requests")
@Tag(name = "Podcast requests")
@SecurityRequirement(name = "bearerAuth")
public class SeriesRequestController {

    private final PodcastRequestService podcastRequestService;

    public SeriesRequestController(PodcastRequestService podcastRequestService) {
        this.podcastRequestService = podcastRequestService;
    }

    @PostMapping
    @Operation(summary = "Listener gửi yêu cầu podcast đến Creator")
    public ResponseEntity<SeriesRequestResponse> create(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody CreateSeriesRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(podcastRequestService.createRequest(userId(jwt), request));
    }

    @GetMapping("/me")
    @Operation(summary = "Listener xem các yêu cầu podcast đã gửi")
    public List<SeriesRequestResponse> getMine(@AuthenticationPrincipal Jwt jwt) {
        return podcastRequestService.getListenerRequests(userId(jwt));
    }

    @GetMapping("/{requestId}/milestones")
    @Operation(summary = "Listener hoặc Creator xem các mốc của yêu cầu đã được chấp nhận")
    public List<MilestoneResponse> getMilestones(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID requestId) {
        return podcastRequestService.getRequestMilestones(userId(jwt), requestId);
    }

    @GetMapping("/{requestId}/messages")
    public List<SeriesRequestMessageResponse> getMessages(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID requestId) {
        return podcastRequestService.getRequestMessages(userId(jwt), requestId);
    }

    @PostMapping("/{requestId}/messages")
    public ResponseEntity<SeriesRequestMessageResponse> sendMessage(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID requestId,
            @Valid @RequestBody SendSeriesRequestMessage request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(podcastRequestService.sendRequestMessage(userId(jwt), requestId, request));
    }

    private UUID userId(Jwt jwt) {
        return UUID.fromString(jwt.getClaimAsString("user_id"));
    }
}
