package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.response.AdminResponses.NotificationItem;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.repository.NotificationRepository;
import java.time.Instant;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserNotificationService {
  private final NotificationRepository notifications;

  public UserNotificationService(NotificationRepository notifications) {
    this.notifications = notifications;
  }

  @Transactional(readOnly = true)
  public Page<NotificationItem> list(UUID user, int page, int size) {
    return notifications
        .findAllByUser_UserIdOrderByCreatedAtDesc(user, AdminSupportService.page(page, size))
        .map(
            n ->
                new NotificationItem(
                    n.getNotificationId(),
                    n.getNotificationType(),
                    n.getTitle(),
                    n.getMessage(),
                    Boolean.TRUE.equals(n.getIsRead()),
                    n.getCreatedAt(),
                    n.getReadAt()));
  }

  @Transactional
  public void read(UUID user, UUID id) {
    var n =
        notifications
            .findByNotificationIdAndUser_UserId(id, user)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thông báo."));
    if (!Boolean.TRUE.equals(n.getIsRead())) {
      n.setIsRead(true);
      n.setReadAt(Instant.now());
    }
  }
}
