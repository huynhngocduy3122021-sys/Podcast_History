package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.exception.*;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.util.*;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;

@Service
public class AdminSupportService {
  private final AppUserRepository users;
  private final AdminAuditRepository audits;
  private final NotificationRepository notifications;
  private final NotificationRealtimePublisher realtime;

  public AdminSupportService(
      AppUserRepository users, AdminAuditRepository audits, NotificationRepository notifications,
      NotificationRealtimePublisher realtime) {
    this.users = users;
    this.audits = audits;
    this.notifications = notifications;
    this.realtime = realtime;
  }

  public AppUser actor(UUID id, boolean adminOnly) {
    AppUser u =
        users
            .findByUserId(id)
            .filter(x -> Boolean.TRUE.equals(x.getIsActive()))
            .orElseThrow(() -> new ResourceForbiddenException("Tài khoản không hoạt động."));
    String role = u.getRole().getRoleCode();
    if (!role.equals("ADMIN") && (adminOnly || !role.equals("STAFF")))
      throw new ResourceForbiddenException("Bạn không có quyền xử lý nghiệp vụ này.");
    return u;
  }

  public AppUser user(UUID id) {
    return users
        .findByUserId(id)
        .filter(x -> Boolean.TRUE.equals(x.getIsActive()))
        .orElseThrow(() -> new ResourceForbiddenException("Tài khoản không hoạt động."));
  }

  public void audit(AppUser actor, String action, String type, UUID id, String note) {
    AdminAudit a = new AdminAudit();
    a.setActor(actor);
    a.setAction(action);
    a.setResourceType(type);
    a.setResourceId(id);
    a.setNote(note);
    audits.save(a);
  }

  public void notify(AppUser user, String type, String title, String message) {
    Notification n = new Notification();
    n.setUser(user);
    n.setNotificationType(type);
    n.setTitle(title.length() > 200 ? title.substring(0, 197) + "..." : title);
    n.setMessage(message);
    n.setIsRead(false);
    realtime.publish(notifications.save(n));
  }

  public static Pageable page(int page, int size) {
    return PageRequest.of(
        Math.max(0, page),
        Math.min(100, Math.max(1, size)),
        Sort.by(Sort.Direction.DESC, "createdAt"));
  }

  public static <T> Specification<T> status(String status) {
    return (r, q, c) ->
        status == null || status.isBlank()
            ? c.conjunction()
            : c.equal(c.upper(r.get("status")), status.trim().toUpperCase(Locale.ROOT));
  }

  public static void state(String actual, String... accepted) {
    if (Arrays.stream(accepted).noneMatch(x -> x.equalsIgnoreCase(actual)))
      throw new ResourceConflictException(
          "Trạng thái hiện tại không cho phép thao tác này: " + actual);
  }
}
