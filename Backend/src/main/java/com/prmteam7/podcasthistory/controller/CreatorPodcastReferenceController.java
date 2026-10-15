package com.prmteam7.podcasthistory.controller;

import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import com.prmteam7.podcasthistory.dto.request.PodcastReferenceRequest;
import com.prmteam7.podcasthistory.dto.response.PodcastReferenceResponse;
import com.prmteam7.podcasthistory.dto.response.ReferenceFileResponse;
import com.prmteam7.podcasthistory.service.PodcastReferenceService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/creator/podcasts/{podcastId}/references")
@Tag(name = "Content Creator - sources", description = "Nguồn tham khảo và tài liệu PDF của podcast")
@SecurityRequirement(name = "bearerAuth")
public class CreatorPodcastReferenceController {
    private final PodcastReferenceService service;

    public CreatorPodcastReferenceController(PodcastReferenceService service) {
        this.service = service;
    }

    @GetMapping
    @Operation(summary = "Danh sách nguồn của podcast thuộc Creator")
    public List<PodcastReferenceResponse> list(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID podcastId) {
        return service.list(userId(jwt), podcastId);
    }

    @GetMapping("/{referenceId}")
    @Operation(summary = "Xem chi tiết nguồn của podcast")
    public PodcastReferenceResponse get(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId, @PathVariable UUID referenceId) {
        return service.get(userId(jwt), podcastId, referenceId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Thêm nguồn tham khảo, sau đó có thể upload PDF vào nguồn này")
    public PodcastReferenceResponse create(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID podcastId,
            @Valid @RequestBody PodcastReferenceRequest request) {
        return service.create(userId(jwt), podcastId, request);
    }

    @PutMapping("/{referenceId}")
    @Operation(summary = "Cập nhật metadata nguồn; giữ file PDF hiện có")
    public PodcastReferenceResponse update(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId, @PathVariable UUID referenceId,
            @Valid @RequestBody PodcastReferenceRequest request) {
        return service.update(userId(jwt), podcastId, referenceId, request);
    }

    @DeleteMapping("/{referenceId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Xóa nguồn và dọn file PDF khỏi R2")
    public void delete(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId, @PathVariable UUID referenceId) {
        service.delete(userId(jwt), podcastId, referenceId);
    }

    @PostMapping(value = "/{referenceId}/file", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Upload hoặc thay file PDF gắn với nguồn và podcast cụ thể")
    public PodcastReferenceResponse upload(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId, @PathVariable UUID referenceId,
            @RequestPart("file") MultipartFile file) {
        return service.uploadPdf(userId(jwt), podcastId, referenceId, file);
    }

    @GetMapping("/{referenceId}/file")
    @Operation(summary = "Lấy URL tải PDF có chữ ký, hiệu lực 5 phút")
    public ReferenceFileResponse download(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId, @PathVariable UUID referenceId) {
        return service.download(userId(jwt), podcastId, referenceId);
    }

    @DeleteMapping("/{referenceId}/file")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Gỡ file PDF, giữ metadata nguồn")
    public void deleteFile(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId, @PathVariable UUID referenceId) {
        service.deleteFile(userId(jwt), podcastId, referenceId);
    }

    private UUID userId(Jwt jwt) {
        return UUID.fromString(jwt.getClaimAsString("user_id"));
    }
}
