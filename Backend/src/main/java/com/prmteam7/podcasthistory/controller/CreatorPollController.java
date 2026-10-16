package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.PollRequests;
import com.prmteam7.podcasthistory.dto.response.PollResponses.*;
import com.prmteam7.podcasthistory.enums.PollStatus;
import com.prmteam7.podcasthistory.service.PollService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/creator/polls")
@Tag(name = "Content Creator - polls", description = "Một câu hỏi, nhiều option lưu trong Polll_questions; chỉ quản lý poll của kênh mình.")
@SecurityRequirement(name = "bearerAuth")
public class CreatorPollController {
    private final PollService polls;

    public CreatorPollController(PollService polls) { this.polls = polls; }

    @GetMapping
    @Operation(summary = "Danh sách poll của kênh, gồm cả bản nháp")
    public Page<Summary> list(@AuthenticationPrincipal Jwt jwt,
            @RequestParam(required = false) PollStatus status,
            @RequestParam(required = false) UUID seriesId,
            @RequestParam(required = false) UUID podcastId,
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return polls.myPolls(id(jwt), status, seriesId, podcastId, page, size);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Tạo poll DRAFT gồm một câu hỏi và 2–20 option")
    public Detail create(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody PollRequests.Write body) {
        return polls.create(id(jwt), body);
    }

    @GetMapping("/{pollId}")
    @Operation(summary = "Chi tiết poll và các option")
    public Detail get(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID pollId) {
        return polls.myPoll(id(jwt), pollId);
    }

    @PutMapping("/{pollId}")
    @Operation(summary = "Sửa câu hỏi/option/thời gian/series/podcast khi poll còn DRAFT")
    public Detail update(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID pollId,
            @Valid @RequestBody PollRequests.Write body) {
        return polls.update(id(jwt), pollId, body);
    }

    @DeleteMapping("/{pollId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Xóa mềm poll, giữ dữ liệu trả lời")
    public void delete(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID pollId) {
        polls.delete(id(jwt), pollId);
    }

    @PostMapping("/{pollId}/publish")
    @Operation(summary = "Công bố poll để người nghe xem và trả lời trong thời hạn")
    public Detail publish(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID pollId) {
        return polls.publish(id(jwt), pollId);
    }

    @PostMapping("/{pollId}/close")
    @Operation(summary = "Đóng poll, ngừng nhận/thay đổi/rút câu trả lời")
    public Detail close(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID pollId) {
        return polls.close(id(jwt), pollId);
    }

    @GetMapping("/{pollId}/results")
    @Operation(summary = "Tổng hợp số lượt và tỷ lệ chọn từng option")
    public Results results(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID pollId) {
        return polls.myResults(id(jwt), pollId);
    }

    @GetMapping("/{pollId}/responses")
    @Operation(summary = "Danh sách người trả lời, chỉ chủ kênh được xem")
    public Page<Response> responses(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID pollId,
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return polls.responses(id(jwt), pollId, page, size);
    }

    private UUID id(Jwt jwt) { return UUID.fromString(jwt.getClaimAsString("user_id")); }
}
