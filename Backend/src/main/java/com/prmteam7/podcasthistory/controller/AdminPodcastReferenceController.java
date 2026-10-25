package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.response.PodcastReferenceResponse;
import com.prmteam7.podcasthistory.dto.response.ReferenceFileResponse;
import com.prmteam7.podcasthistory.service.PodcastReferenceService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/admin/podcasts/{podcastId}/references")
@Tag(name = "Admin - podcast sources", description = "Admin và Staff xem nguồn tham khảo của podcast")
@SecurityRequirement(name = "bearerAuth")
public class AdminPodcastReferenceController {
  private final PodcastReferenceService service;

  public AdminPodcastReferenceController(PodcastReferenceService service) {
    this.service = service;
  }

  @GetMapping
  @Operation(summary = "Admin xem nguồn để kiểm duyệt podcast")
  public List<PodcastReferenceResponse> list(@PathVariable UUID podcastId) {
    return service.listForAdmin(podcastId);
  }

  @GetMapping("/{referenceId}/file")
  @Operation(summary = "Admin lấy URL tải PDF nguồn có chữ ký")
  public ReferenceFileResponse download(
      @PathVariable UUID podcastId, @PathVariable UUID referenceId) {
    return service.downloadForAdmin(podcastId, referenceId);
  }
}
