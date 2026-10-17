package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.PollRequests;
import com.prmteam7.podcasthistory.dto.response.PollResponses.*;
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
@RequestMapping("/api")
@Tag(name = "Listener - polls", description = "Xem poll đã công bố; mỗi Listener chỉ có một câu trả lời cho mỗi poll.")
@SecurityRequirement(name = "bearerAuth")
public class PollController {
    private final PollService polls;

    public PollController(PollService polls) { this.polls = polls; }

    @GetMapping("/creators/{creatorId}/polls")
    @Operation(summary = "Danh sách poll đã công bố của một kênh")
    public Page<Summary> list(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID creatorId,
            @RequestParam(required = false) UUID seriesId,
            @RequestParam(required = false) UUID podcastId,
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return polls.available(id(jwt), creatorId, seriesId, podcastId, page, size);
    }

    @GetMapping("/polls/{pollId}")
    @Operation(summary = "Xem câu hỏi và các option của poll đã công bố")
    public Detail get(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID pollId) {
        return polls.view(id(jwt), pollId);
    }

    @GetMapping("/polls/{pollId}/results")
    @Operation(summary = "Xem kết quả tổng hợp, không lộ danh sách người trả lời")
    public Results results(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID pollId) {
        return polls.publicResults(id(jwt), pollId);
    }

    @PostMapping("/polls/{pollId}/responses")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Listener chọn một option; gửi lặp trả 409")
    public Response answer(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID pollId,
            @Valid @RequestBody PollRequests.Answer body) {
        return polls.answer(id(jwt), pollId, body, false);
    }

    @GetMapping("/polls/{pollId}/responses/me")
    @Operation(summary = "Xem câu trả lời của tôi; chưa trả lời thì 404")
    public Response mine(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID pollId) {
        return polls.myResponse(id(jwt), pollId);
    }

    @PutMapping("/polls/{pollId}/responses/me")
    @Operation(summary = "Đổi lựa chọn của tôi khi poll còn nhận trả lời")
    public Response change(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID pollId,
            @Valid @RequestBody PollRequests.Answer body) {
        return polls.answer(id(jwt), pollId, body, true);
    }

    @DeleteMapping("/polls/{pollId}/responses/me")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    @Operation(summary = "Rút câu trả lời của tôi khi poll còn nhận trả lời")
    public void withdraw(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID pollId) {
        polls.withdraw(id(jwt), pollId);
    }

    private UUID id(Jwt jwt) { return UUID.fromString(jwt.getClaimAsString("user_id")); }
}
