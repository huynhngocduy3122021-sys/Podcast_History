package com.prmteam7.podcasthistory.controller;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.prmteam7.podcasthistory.dto.request.CreatorRequests.PodcastWrite;
import com.prmteam7.podcasthistory.dto.request.CreatorRequests.SeriesAssignment;
import com.prmteam7.podcasthistory.dto.request.CreatorRequests.SeriesWrite;
import com.prmteam7.podcasthistory.dto.response.CreatorResponses.PodcastItem;
import com.prmteam7.podcasthistory.dto.response.CreatorResponses.PodcastVideoItem;
import com.prmteam7.podcasthistory.dto.response.CreatorResponses.SeriesItem;
import com.prmteam7.podcasthistory.service.CreatorFlowService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/creator")
@Tag(name = "Content Creator", description = "Quản lý series, podcast, upload ảnh bìa, video/audio và gửi duyệt")
@SecurityRequirement(name = "bearerAuth")
public class CreatorFlowController {

    private final CreatorFlowService creatorFlowService;

    public CreatorFlowController(CreatorFlowService creatorFlowService) {
        this.creatorFlowService = creatorFlowService;
    }

    @GetMapping("/series")
    @Operation(summary = "Danh sách series thuộc kênh Creator hiện tại")
    public List<SeriesItem> listSeries(@AuthenticationPrincipal Jwt jwt) {
        return creatorFlowService.listSeries(userId(jwt));
    }

    @PostMapping("/series")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Tạo series")
    public SeriesItem createSeries(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody SeriesWrite request) {
        return creatorFlowService.createSeries(userId(jwt), request);
    }

    @GetMapping("/series/{seriesId}")
    @Operation(summary = "Xem một series thuộc kênh Creator hiện tại")
    public SeriesItem getSeries(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID seriesId) {
        return creatorFlowService.getSeries(userId(jwt), seriesId);
    }

    @GetMapping("/series/{seriesId}/podcasts")
    @Operation(summary = "Danh sách podcast đã gắn vào series của kênh")
    public List<PodcastItem> listSeriesPodcasts(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID seriesId) {
        return creatorFlowService.listSeriesPodcasts(userId(jwt), seriesId);
    }

    @PutMapping("/series/{seriesId}")
    @Operation(summary = "Cập nhật series")
    public SeriesItem updateSeries(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID seriesId,
            @Valid @RequestBody SeriesWrite request) {
        return creatorFlowService.updateSeries(userId(jwt), seriesId, request);
    }

    @DeleteMapping("/series/{seriesId}")
    @Operation(summary = "Lưu trữ series")
    public SeriesItem archiveSeries(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID seriesId) {
        return creatorFlowService.archiveSeries(userId(jwt), seriesId);
    }

    @GetMapping("/podcasts")
    @Operation(summary = "Danh sách podcast thuộc kênh Creator hiện tại")
    public List<PodcastItem> listPodcasts(@AuthenticationPrincipal Jwt jwt) {
        return creatorFlowService.listPodcasts(userId(jwt));
    }

    @PostMapping("/podcasts")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Tạo podcast nháp thuộc kênh Creator, chưa cần series hoặc video")
    public PodcastItem createPodcast(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody PodcastWrite request) {
        return creatorFlowService.createPodcast(userId(jwt), request);
    }

    @GetMapping("/podcasts/{podcastId}")
    @Operation(summary = "Xem podcast của Creator kèm URL video",
            description = "Trả videoUrl và videoUrlExpiresAt; chưa upload hoặc đã xóa thì videoUrl là null.")
    public PodcastItem getPodcast(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID podcastId) {
        return creatorFlowService.getPodcast(userId(jwt), podcastId);
    }

    @PutMapping("/podcasts/{podcastId}")
    @Operation(summary = "Cập nhật podcast; nội dung đã duyệt sẽ quay về nháp")
    public PodcastItem updatePodcast(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId,
            @Valid @RequestBody PodcastWrite request) {
        return creatorFlowService.updatePodcast(userId(jwt), podcastId, request);
    }

    @PutMapping("/podcasts/{podcastId}/series")
    @Operation(summary = "Gắn podcast hiện có vào series của kênh")
    public PodcastItem assignPodcastToSeries(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId,
            @Valid @RequestBody SeriesAssignment request) {
        return creatorFlowService.assignPodcastToSeries(userId(jwt), podcastId, request.seriesId());
    }

    @DeleteMapping("/podcasts/{podcastId}/series")
    @Operation(summary = "Gỡ podcast khỏi series; podcast vẫn thuộc kênh và giữ trạng thái duyệt")
    public PodcastItem removePodcastFromSeries(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID podcastId) {
        return creatorFlowService.removePodcastFromSeries(userId(jwt), podcastId);
    }

    @PostMapping(value = "/podcasts/{podcastId}/video", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Upload video hoặc audio và gắn media vào podcast được chỉ định")
    public PodcastVideoItem uploadVideo(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId,
            @RequestPart("file") MultipartFile file) {
        return creatorFlowService.uploadPodcastVideo(userId(jwt), podcastId, file);
    }

    @PostMapping(value = "/podcasts/{podcastId}/thumbnail", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Upload ảnh bìa podcast", description = "Gửi multipart/form-data với field file. Trả về podcast đã cập nhật thumbnailUrl.")
    public PodcastItem uploadThumbnail(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId,
            @RequestPart("file") MultipartFile file) {
        return creatorFlowService.uploadPodcastThumbnail(userId(jwt), podcastId, file);
    }

    @PostMapping("/podcasts/{podcastId}/submit")
    @Operation(summary = "Gửi podcast có video hoặc audio cho Admin duyệt")
    public PodcastItem submitPodcast(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID podcastId) {
        return creatorFlowService.submitPodcast(userId(jwt), podcastId);
    }

    @DeleteMapping("/podcasts/{podcastId}")
    @Operation(summary = "Đánh dấu podcast là DELETED")
    public PodcastItem archivePodcast(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID podcastId) {
        return creatorFlowService.archivePodcast(userId(jwt), podcastId);
    }

    private UUID userId(Jwt jwt) {
        return UUID.fromString(jwt.getClaimAsString("user_id"));
    }
}
