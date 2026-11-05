package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.prmteam7.podcasthistory.dto.request.AdminRequests.ResolveReport;
import com.prmteam7.podcasthistory.dto.request.ListenerRequests.ReportCreate;
import com.prmteam7.podcasthistory.dto.response.LivestreamResponses.AgoraJoin;
import com.prmteam7.podcasthistory.enums.ReportAction;
import com.prmteam7.podcasthistory.exception.ResourceForbiddenException;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class LivestreamReportWorkflowTest {
  @Mock AppUserRepository users;
  @Mock LivestreamRepository livestreams;
  @Mock ReportRepository reports;
  @InjectMocks ListenerFlowService listenerFlow;

  @Test
  void listenerCanReportAnActiveLivestream() {
    UUID listenerId = UUID.randomUUID();
    AppUser listener = new AppUser();
    listener.setUserId(listenerId);
    listener.setIsActive(true);
    Livestream live = live();
    when(users.findById(listenerId)).thenReturn(Optional.of(listener));
    when(livestreams.findById(live.getLivestreamId())).thenReturn(Optional.of(live));
    when(reports.save(any(Report.class))).thenAnswer(call -> call.getArgument(0));

    var result = listenerFlow.createReport(listenerId,
        new ReportCreate("LIVESTREAM", live.getLivestreamId(), "FALSE_HISTORY", "Nói sai sự kiện"));

    assertEquals("LIVESTREAM", result.targetType());
    assertEquals(live.getLivestreamId(), result.targetId());
    assertEquals("PENDING", result.status());
    verify(reports).save(argThat(report -> report.getLivestream() == live));
  }

  @Test
  void stoppingFourthViolatingLivestreamEndsItAndBansFutureStreams() {
    AdminSupportService support = mock(AdminSupportService.class);
    ProducerProfileRepository creators = mock(ProducerProfileRepository.class);
    ModerationReviewRepository reviews = mock(ModerationReviewRepository.class);
    AgoraRtcTokenService agora = mock(AgoraRtcTokenService.class);
    RealtimeEventPublisher realtime = mock(RealtimeEventPublisher.class);
    AdminContentService admin = new AdminContentService(support, reports,
        mock(PodcastRepository.class), mock(CommentRepository.class), reviews,
        mock(PodcastAppealRepository.class), livestreams, creators, agora, realtime);
    Livestream live = live();
    UUID reviewerId = UUID.randomUUID();
    AppUser reviewer = new AppUser();
    reviewer.setUserId(reviewerId);
    Report report = new Report();
    report.setReportId(UUID.randomUUID());
    report.setUser(new AppUser());
    report.setLivestream(live);
    report.setStatus("PENDING");
    when(support.actor(reviewerId, false)).thenReturn(reviewer);
    when(reports.lockById(report.getReportId())).thenReturn(Optional.of(report));
    when(creators.findByIdForUpdate(live.getProducerProfile().getProducerProfileId()))
        .thenReturn(Optional.of(live.getProducerProfile()));
    when(livestreams.lockById(live.getLivestreamId())).thenReturn(Optional.of(live));
    when(reports.countStoppedLivestreamsByCreator(live.getProducerProfile().getProducerProfileId()))
        .thenReturn(3L);
    when(reports.save(report)).thenReturn(report);
    when(reviews.findAllByReport_ReportIdOrderByReviewedAtDesc(report.getReportId()))
        .thenReturn(java.util.List.of());

    var result = admin.resolve(reviewerId, report.getReportId(),
        new ResolveReport(ReportAction.STOP_LIVESTREAM, "Nói sai lịch sử"));

    assertEquals("RESOLVED", result.status());
    assertEquals("ENDED", live.getStatus());
    assertNotNull(live.getEndedAt());
    verify(reviews).save(argThat(review -> "STOP_LIVESTREAM".equals(review.getDecision())));
    verify(support).notify(eq(live.getUser()), eq("LIVESTREAM_MODERATION"),
        eq("Kênh bị cấm livestream"), contains("4"));
    verify(realtime).publishTopic(eq("/topic/livestreams"), eq("LIVESTREAM_UPDATED"), any());

    Report secondReport = new Report();
    secondReport.setReportId(UUID.randomUUID());
    secondReport.setLivestream(live);
    secondReport.setStatus("PENDING");
    when(reports.lockById(secondReport.getReportId())).thenReturn(Optional.of(secondReport));
    assertThrows(ResourceConflictException.class,
        () -> admin.resolve(reviewerId, secondReport.getReportId(),
            new ResolveReport(ReportAction.STOP_LIVESTREAM, "Báo cáo trùng")));
    verify(reviews, times(1)).save(any(ModerationReview.class));

    LivestreamService liveService = new LivestreamService(livestreams, creators, users, agora,
        mock(AgoraChatTokenService.class), realtime, mock(AudienceNotificationService.class), reports);
    live.setStatus("DRAFT");
    when(creators.findByUserIdForUpdate(live.getUser().getUserId()))
        .thenReturn(Optional.of(live.getProducerProfile()));
    when(livestreams.findById(live.getLivestreamId())).thenReturn(Optional.of(live));
    when(reports.countStoppedLivestreamsByCreator(live.getProducerProfile().getProducerProfileId()))
        .thenReturn(4L);
    assertThrows(ResourceForbiddenException.class,
        () -> liveService.start(live.getUser().getUserId(), live.getLivestreamId()));
  }

  @Test
  void reviewerCanGetAudienceTokenForReportedLive() {
    AdminSupportService support = mock(AdminSupportService.class);
    AgoraRtcTokenService agora = mock(AgoraRtcTokenService.class);
    AdminContentService admin = new AdminContentService(support, reports,
        mock(PodcastRepository.class), mock(CommentRepository.class),
        mock(ModerationReviewRepository.class), mock(PodcastAppealRepository.class),
        livestreams, mock(ProducerProfileRepository.class), agora,
        mock(RealtimeEventPublisher.class));
    UUID reviewerId = UUID.randomUUID();
    Livestream live = live();
    Report report = new Report();
    report.setReportId(UUID.randomUUID());
    report.setLivestream(live);
    when(reports.findById(report.getReportId())).thenReturn(Optional.of(report));
    AgoraJoin token = mock(AgoraJoin.class);
    when(agora.issue(live, reviewerId, false)).thenReturn(token);

    assertSame(token, admin.joinReportedLivestream(reviewerId, report.getReportId()));
    assertEquals("LIVE", admin.reportedLivestream(reviewerId, report.getReportId()).status());
    verify(support, times(2)).actor(reviewerId, false);
  }

  @Test
  void endedLivestreamDetailRemainsVisibleForViewerStatusPolling() {
    Livestream live = live();
    live.setStatus("ENDED");
    when(livestreams.findById(live.getLivestreamId())).thenReturn(Optional.of(live));
    LivestreamService service = new LivestreamService(livestreams,
        mock(ProducerProfileRepository.class), users, mock(AgoraRtcTokenService.class),
        mock(AgoraChatTokenService.class), mock(RealtimeEventPublisher.class),
        mock(AudienceNotificationService.class), reports);

    assertEquals("ENDED", service.visible(live.getLivestreamId()).status());
  }

  private static Livestream live() {
    AppUser creator = new AppUser();
    creator.setUserId(UUID.randomUUID());
    creator.setIsActive(true);
    Role role = new Role();
    role.setRoleCode("CREATOR");
    creator.setRole(role);
    ProducerProfile profile = new ProducerProfile();
    profile.setProducerProfileId(UUID.randomUUID());
    profile.setVerificationStatus("APPROVED");
    profile.setUser(creator);
    Livestream live = new Livestream();
    live.setLivestreamId(UUID.randomUUID());
    live.setUser(creator);
    live.setProducerProfile(profile);
    live.setTitle("Buổi phát lịch sử");
    live.setStatus("LIVE");
    return live;
  }
}
