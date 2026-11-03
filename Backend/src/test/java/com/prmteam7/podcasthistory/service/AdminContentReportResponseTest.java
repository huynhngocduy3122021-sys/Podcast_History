package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;

class AdminContentReportResponseTest {
  @Test
  void reportListContainsNamesForEachTargetAndAssignee() {
    AdminSupportService support = mock(AdminSupportService.class);
    ReportRepository reports = mock(ReportRepository.class);
    AdminContentService service = new AdminContentService(
        support, reports, mock(PodcastRepository.class), mock(CommentRepository.class),
        mock(ModerationReviewRepository.class), mock(PodcastAppealRepository.class));

    AppUser reporter = mock(AppUser.class);
    when(reporter.getUserId()).thenReturn(UUID.randomUUID());
    when(reporter.getDisplayName()).thenReturn("Người báo cáo");
    AppUser assignee = mock(AppUser.class);
    when(assignee.getUserId()).thenReturn(UUID.randomUUID());
    when(assignee.getDisplayName()).thenReturn("Nhân viên duyệt");

    Report podcastReport = mock(Report.class);
    Podcast podcast = mock(Podcast.class);
    when(podcast.getPodcastId()).thenReturn(UUID.randomUUID());
    when(podcast.getTitle()).thenReturn("Lịch sử Việt Nam");
    when(podcastReport.getPodcast()).thenReturn(podcast);

    Report commentReport = mock(Report.class);
    Comment comment = mock(Comment.class);
    when(comment.getCommentId()).thenReturn(UUID.randomUUID());
    when(comment.getContent()).thenReturn("Nội dung   bình luận\nđược báo cáo");
    when(commentReport.getComment()).thenReturn(comment);

    Report livestreamReport = mock(Report.class);
    Livestream livestream = mock(Livestream.class);
    when(livestream.getLivestreamId()).thenReturn(UUID.randomUUID());
    when(livestream.getTitle()).thenReturn("Buổi phát trực tiếp");
    when(livestreamReport.getLivestream()).thenReturn(livestream);

    for (Report report : List.of(podcastReport, commentReport, livestreamReport)) {
      when(report.getReportId()).thenReturn(UUID.randomUUID());
      when(report.getUser()).thenReturn(reporter);
      when(report.getAssignedTo()).thenReturn(assignee);
    }
    when(reports.findAll(any(Specification.class), any(Pageable.class)))
        .thenReturn(new PageImpl<>(List.of(podcastReport, commentReport, livestreamReport)));

    var items = service.listReports(UUID.randomUUID(), "PENDING", 0, 20).getContent();
    assertEquals(List.of("Lịch sử Việt Nam", "Nội dung bình luận được báo cáo", "Buổi phát trực tiếp"),
        items.stream().map(item -> item.targetName()).toList());
    assertEquals(List.of("Nhân viên duyệt", "Nhân viên duyệt", "Nhân viên duyệt"),
        items.stream().map(item -> item.assigneeName()).toList());
  }
}
