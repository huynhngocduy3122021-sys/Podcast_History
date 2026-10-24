package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.Notification;
import com.prmteam7.podcasthistory.model.Podcast;
import com.prmteam7.podcasthistory.config.PackageFeatures;
import com.prmteam7.podcasthistory.repository.FollowRepository;
import com.prmteam7.podcasthistory.repository.NotificationRepository;
import com.prmteam7.podcasthistory.repository.SubscriptionRepository;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;
import tools.jackson.databind.ObjectMapper;

@Service
public class AudienceNotificationService {
  private final NotificationRepository notifications;
  private final FollowRepository follows;
  private final SubscriptionRepository subscriptions;
  private final PackageFeatures packageFeatures;
  private final ObjectMapper mapper;

  public AudienceNotificationService(
      NotificationRepository notifications, FollowRepository follows,
      SubscriptionRepository subscriptions, PackageFeatures packageFeatures,
      ObjectMapper mapper) {
    this.notifications = notifications;
    this.follows = follows;
    this.subscriptions = subscriptions;
    this.packageFeatures = packageFeatures;
    this.mapper = mapper;
  }

  public void newPodcast(Podcast podcast) {
    if (!"APPROVED".equalsIgnoreCase(podcast.getProducerProfile().getVerificationStatus())
        || !Boolean.TRUE.equals(podcast.getProducerProfile().getUser().getIsActive())
        || !Boolean.TRUE.equals(podcast.getCategory().getIsActive())) return;
    UUID creatorId = podcast.getProducerProfile().getProducerProfileId();
    String channelName = podcast.getProducerProfile().getChannelName();
    for (AppUser listener : follows.findActiveListenersByCreatorId(creatorId)) {
      if (packageFeatures.membershipsEnabled() && Boolean.TRUE.equals(podcast.getIsExclusive())) {
        Instant now = Instant.now();
        if (!subscriptions
            .existsByUser_UserIdAndMembershipPlan_ProducerProfile_ProducerProfileIdAndStatusIgnoreCaseAndStartAtBeforeAndEndAtAfter(
                listener.getUserId(), creatorId, "ACTIVE", now, now)) continue;
      }
      send(listener, "NEW_PODCAST", "Podcast mới từ " + channelName,
          channelName + " vừa đăng: " + podcast.getTitle(),
          Map.of("podcastId", podcast.getPodcastId(), "creatorId", creatorId));
    }
  }

  public void newFollower(AppUser creator, AppUser listener, UUID creatorId) {
    send(creator, "NEW_FOLLOWER", "Người theo dõi mới",
        listener.getDisplayName() + " vừa theo dõi kênh của bạn.",
        Map.of("creatorId", creatorId, "listenerId", listener.getUserId()));
  }

  public void newComment(Podcast podcast, AppUser listener, UUID commentId) {
    AppUser creator = podcast.getProducerProfile().getUser();
    if (creator.getUserId().equals(listener.getUserId())) return;
    send(creator, "NEW_COMMENT", "Bình luận mới",
        listener.getDisplayName() + " vừa bình luận về podcast: " + podcast.getTitle(),
        Map.of("podcastId", podcast.getPodcastId(), "commentId", commentId,
            "listenerId", listener.getUserId()));
  }

  public void newMembership(AppUser creator, AppUser listener, UUID creatorId,
      UUID subscriptionId, UUID planId) {
    send(creator, "NEW_MEMBERSHIP", "Thành viên mới",
        listener.getDisplayName() + " vừa mua gói thành viên của kênh bạn.",
        Map.of("creatorId", creatorId, "subscriptionId", subscriptionId,
            "membershipPlanId", planId, "listenerId", listener.getUserId()));
  }

  private void send(AppUser recipient, String type, String title, String message,
      Map<String, UUID> payload) {
    if (!Boolean.TRUE.equals(recipient.getIsActive())) return;
    Notification notification = new Notification();
    notification.setUser(recipient);
    notification.setNotificationType(type);
    notification.setTitle(title);
    notification.setMessage(message);
    notification.setPayload(mapper.valueToTree(payload));
    notification.setIsRead(false);
    notifications.save(notification);
  }
}
