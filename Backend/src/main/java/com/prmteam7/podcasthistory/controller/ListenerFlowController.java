package com.prmteam7.podcasthistory.controller;

import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import com.prmteam7.podcasthistory.dto.request.ListenerRequests.CommentCreate;
import com.prmteam7.podcasthistory.dto.request.ListenerRequests.CommentUpdate;
import com.prmteam7.podcasthistory.dto.request.ListenerRequests.ListeningProgress;
import com.prmteam7.podcasthistory.dto.request.ListenerRequests.MembershipCheckout;
import com.prmteam7.podcasthistory.dto.request.ListenerRequests.ReportCreate;
import com.prmteam7.podcasthistory.dto.request.ListenerRequests.ReportUpdate;
import com.prmteam7.podcasthistory.dto.request.ListenerRequests.SeriesRequestCreate;
import com.prmteam7.podcasthistory.dto.request.ListenerRequests.SeriesRequestUpdate;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.CommentItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.CreatorItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.FollowItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.LikeSummary;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.ListeningHistoryItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.MembershipCheckoutItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.MembershipPlanItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.PlaybackItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.PodcastItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.ReportItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.SavedPodcastItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.SeriesRequestItem;
import com.prmteam7.podcasthistory.dto.response.ListenerResponses.SubscriptionItem;
import com.prmteam7.podcasthistory.service.ListenerFlowService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api")
@Tag(name = "Listener flow", description = "Khám phá podcast và các chức năng dành cho Listener")
@SecurityRequirement(name = "bearerAuth")
public class ListenerFlowController {

    private final ListenerFlowService listenerFlowService;

    public ListenerFlowController(ListenerFlowService listenerFlowService) {
        this.listenerFlowService = listenerFlowService;
    }

    @GetMapping("/podcasts")
    @Operation(summary = "Tìm kiếm và khám phá podcast đã xuất bản")
    public Page<PodcastItem> searchPodcasts(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) UUID categoryId,
            @RequestParam(required = false) UUID creatorId,
            @RequestParam(required = false) UUID seriesId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return listenerFlowService.searchPodcasts(q, categoryId, creatorId, seriesId, page, size);
    }

    @GetMapping("/podcasts/{podcastId}")
    @Operation(summary = "Xem chi tiết podcast")
    public PodcastItem getPodcast(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID podcastId) {
        return listenerFlowService.getPodcast(userId(jwt), podcastId);
    }

    @GetMapping("/creators")
    @Operation(summary = "Danh sách creator đã được duyệt")
    public List<CreatorItem> getCreators() {
        return listenerFlowService.getCreators();
    }

    @GetMapping("/creators/{creatorId}")
    @Operation(summary = "Xem thông tin kênh creator")
    public CreatorItem getCreator(@PathVariable UUID creatorId) {
        return listenerFlowService.getCreator(creatorId);
    }

    @GetMapping("/podcasts/{podcastId}/playback")
    @Operation(summary = "Kiểm tra quyền và lấy URL phát podcast")
    public PlaybackItem getPlayback(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId) {
        return listenerFlowService.getPlayback(userId(jwt), podcastId);
    }

    @PutMapping("/podcasts/{podcastId}/listening-progress")
    @Operation(summary = "Tạo hoặc cập nhật tiến độ nghe")
    public ListeningHistoryItem saveProgress(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId,
            @Valid @RequestBody ListeningProgress request) {
        return listenerFlowService.saveProgress(userId(jwt), podcastId, request);
    }

    @GetMapping("/me/listening-history")
    @Operation(summary = "Xem lịch sử nghe")
    public Page<ListeningHistoryItem> getListeningHistory(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return listenerFlowService.getListeningHistory(userId(jwt), page, size);
    }

    @GetMapping("/me/listening-history/{podcastId}")
    @Operation(summary = "Xem tiến độ nghe của một podcast")
    public ListeningHistoryItem getListeningHistory(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId) {
        return listenerFlowService.getListeningHistory(userId(jwt), podcastId);
    }

    @DeleteMapping("/me/listening-history/{podcastId}")
    public ResponseEntity<Void> deleteListeningHistory(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId) {
        listenerFlowService.deleteListeningHistory(userId(jwt), podcastId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/podcasts/{podcastId}/likes")
    @Operation(summary = "Xem số lượt thích và trạng thái của Listener")
    public LikeSummary getLikes(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId) {
        return listenerFlowService.getLikeSummary(userId(jwt), podcastId);
    }

    @PutMapping("/podcasts/{podcastId}/like")
    @Operation(summary = "Thích podcast; thao tác gọi lặp là an toàn")
    public LikeSummary likePodcast(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId) {
        return listenerFlowService.likePodcast(userId(jwt), podcastId);
    }

    @DeleteMapping("/podcasts/{podcastId}/like")
    @Operation(summary = "Bỏ thích podcast")
    public LikeSummary unlikePodcast(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId) {
        return listenerFlowService.unlikePodcast(userId(jwt), podcastId);
    }

    @GetMapping("/podcasts/{podcastId}/comments")
    @Operation(summary = "Xem bình luận của podcast")
    public Page<CommentItem> getComments(
            @PathVariable UUID podcastId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return listenerFlowService.getComments(podcastId, page, size);
    }

    @PostMapping("/podcasts/{podcastId}/comments")
    @Operation(summary = "Tạo bình luận")
    public ResponseEntity<CommentItem> createComment(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId,
            @Valid @RequestBody CommentCreate request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(listenerFlowService.createComment(userId(jwt), podcastId, request));
    }

    @GetMapping(value = "/podcasts/{podcastId}/comments/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    @Operation(summary = "Nhận bình luận mới theo thời gian thực qua Server-Sent Events")
    public SseEmitter streamComments(@PathVariable UUID podcastId) {
        return listenerFlowService.subscribeToComments(podcastId);
    }

    @PutMapping("/comments/{commentId}")
    @Operation(summary = "Cập nhật bình luận của chính Listener")
    public CommentItem updateComment(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID commentId,
            @Valid @RequestBody CommentUpdate request) {
        return listenerFlowService.updateComment(userId(jwt), commentId, request);
    }

    @DeleteMapping("/comments/{commentId}")
    public ResponseEntity<Void> deleteComment(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID commentId) {
        listenerFlowService.deleteComment(userId(jwt), commentId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/reports")
    @Operation(summary = "Báo cáo podcast hoặc bình luận")
    public ResponseEntity<ReportItem> createReport(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody ReportCreate request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(listenerFlowService.createReport(userId(jwt), request));
    }

    @GetMapping("/me/reports")
    public Page<ReportItem> getReports(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return listenerFlowService.getReports(userId(jwt), page, size);
    }

    @PatchMapping("/me/reports/{reportId}")
    public ReportItem updateReport(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID reportId,
            @Valid @RequestBody ReportUpdate request) {
        return listenerFlowService.updateReport(userId(jwt), reportId, request);
    }

    @DeleteMapping("/me/reports/{reportId}")
    public ResponseEntity<Void> deleteReport(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID reportId) {
        listenerFlowService.deleteReport(userId(jwt), reportId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/me/follows")
    @Operation(summary = "Danh sách creator đang theo dõi")
    public Page<FollowItem> getFollows(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return listenerFlowService.getFollows(userId(jwt), page, size);
    }

    @PutMapping("/creators/{creatorId}/follow")
    @Operation(summary = "Theo dõi creator")
    public FollowItem followCreator(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID creatorId) {
        return listenerFlowService.followCreator(userId(jwt), creatorId);
    }

    @DeleteMapping("/creators/{creatorId}/follow")
    public ResponseEntity<Void> unfollowCreator(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID creatorId) {
        listenerFlowService.unfollowCreator(userId(jwt), creatorId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/me/saved-podcasts")
    @Operation(summary = "Danh sách podcast đã lưu")
    public Page<SavedPodcastItem> getSavedPodcasts(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return listenerFlowService.getSavedPodcasts(userId(jwt), page, size);
    }

    @PutMapping("/me/saved-podcasts/{podcastId}")
    @Operation(summary = "Lưu podcast vào danh sách yêu thích")
    public SavedPodcastItem savePodcast(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId) {
        return listenerFlowService.savePodcast(userId(jwt), podcastId);
    }

    @DeleteMapping("/me/saved-podcasts/{podcastId}")
    public ResponseEntity<Void> unsavePodcast(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID podcastId) {
        listenerFlowService.unsavePodcast(userId(jwt), podcastId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/creators/{creatorId}/membership-plans")
    @Operation(summary = "Xem các membership plan đang hoạt động của creator")
    public List<MembershipPlanItem> getMembershipPlans(@PathVariable UUID creatorId) {
        return listenerFlowService.getMembershipPlans(creatorId);
    }

    @GetMapping("/me/subscriptions")
    @Operation(summary = "Xem các membership của Listener")
    public List<SubscriptionItem> getSubscriptions(@AuthenticationPrincipal Jwt jwt) {
        return listenerFlowService.getSubscriptions(userId(jwt));
    }

    @PostMapping("/me/subscriptions")
    @Operation(summary = "Tạo checkout membership ở trạng thái chờ thanh toán")
    public ResponseEntity<MembershipCheckoutItem> createMembershipCheckout(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody MembershipCheckout request) {
        return ResponseEntity.accepted()
                .body(listenerFlowService.createMembershipCheckout(userId(jwt), request));
    }

    @DeleteMapping("/me/subscriptions/{subscriptionId}")
    public ResponseEntity<Void> cancelSubscription(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID subscriptionId) {
        listenerFlowService.cancelSubscription(userId(jwt), subscriptionId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/me/series-requests")
    @Operation(summary = "Danh sách yêu cầu đã gửi cho creator")
    public List<SeriesRequestItem> getSeriesRequests(@AuthenticationPrincipal Jwt jwt) {
        return listenerFlowService.getSeriesRequests(userId(jwt));
    }

    @PostMapping("/creators/{creatorId}/series-requests")
    @Operation(summary = "Gửi yêu cầu podcast tới creator có membership")
    public ResponseEntity<SeriesRequestItem> createSeriesRequest(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID creatorId,
            @Valid @RequestBody SeriesRequestCreate request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(listenerFlowService.createSeriesRequest(userId(jwt), creatorId, request));
    }

    @PutMapping("/me/series-requests/{requestId}")
    @Operation(summary = "Cập nhật yêu cầu khi creator chưa phản hồi")
    public SeriesRequestItem updateSeriesRequest(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID requestId,
            @Valid @RequestBody SeriesRequestUpdate request) {
        return listenerFlowService.updateSeriesRequest(userId(jwt), requestId, request);
    }

    @DeleteMapping("/me/series-requests/{requestId}")
    public ResponseEntity<Void> cancelSeriesRequest(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID requestId) {
        listenerFlowService.cancelSeriesRequest(userId(jwt), requestId);
        return ResponseEntity.noContent().build();
    }

    private UUID userId(Jwt jwt) {
        return UUID.fromString(jwt.getClaimAsString("user_id"));
    }
}
