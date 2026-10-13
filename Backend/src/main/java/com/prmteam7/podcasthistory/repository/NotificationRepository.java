package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.Notification;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.repository.*;

public interface NotificationRepository extends JpaRepository<Notification, UUID> {
  Page<Notification> findAllByUser_UserIdOrderByCreatedAtDesc(UUID id, Pageable page);

  Optional<Notification> findByNotificationIdAndUser_UserId(UUID id, UUID userId);
}
