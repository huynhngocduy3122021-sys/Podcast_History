package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.Notification;
import com.prmteam7.podcasthistory.model.Poll;
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
  private final NotificationRealtimePublisher realtime;

  public AudienceNotificationService(
      NotificationRepository notifications, FollowRepository follows,
      SubscriptionRepository subscriptions, PackageFeatures packageFeatures,
      ObjectMapper mapper, NotificationRealtimePublisher realtime) {
    this.notifications = notifications;
    this.follows = follows;
    this.subscriptions = subscriptions;
    this.packageFeatures = packageFeatures;
    this.mapper = mapper;
    this.realtime = realtime;
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
      send(listener, "NEW_PODCAST", channelName + " vừa đăng: " + podcast.getTitle(),
          channelName + " vừa đăng: " + podcast.getTitle(),
          Map.of("podcastId", podcast.getPodcastId(), "creatorId", creatorId));
    }
  }

  public void newFollower(AppUser creator, AppUser listener, UUID creatorId) {
    send(creator, "NEW_FOLLOWER", listener.getDisplayName() + " vừa theo dõi kênh của bạn",
        listener.getDisplayName() + " vừa theo dõi kênh của bạn.",
        Map.of("creatorId", creatorId, "listenerId", listener.getUserId()));
  }

  public void newComment(Podcast podcast, AppUser listener, UUID commentId) {
    AppUser creator = podcast.getProducerProfile().getUser();
    if (creator.getUserId().equals(listener.getUserId())) return;
    send(creator, "NEW_COMMENT",
        listener.getDisplayName() + " bình luận về: " + podcast.getTitle(),
        listener.getDisplayName() + " vừa bình luận về podcast: " + podcast.getTitle(),
        Map.of("podcastId", podcast.getPodcastId(), "commentId", commentId,
            "listenerId", listener.getUserId()));
  }

  public void newMembership(AppUser creator, AppUser listener, UUID creatorId,
      UUID subscriptionId, UUID planId) {
    send(creator, "NEW_MEMBERSHIP", listener.getDisplayName() + " đã mua gói thành viên",
        listener.getDisplayName() + " vừa mua gói thành viên của kênh bạn.",
        Map.of("creatorId", creatorId, "subscriptionId", subscriptionId,
            "membershipPlanId", planId, "listenerId", listener.getUserId()));
  }

  /** Notify followers when a Creator publishes a poll. */
  public void newPoll(Poll poll) {
    if (poll == null || poll.getProducerProfile() == null
        || poll.getPollId() == null) return;
    UUID creatorId = poll.getProducerProfile().getProducerProfileId();
    String channelName = poll.getProducerProfile().getChannelName();
    String question = poll.getQuestion();
    for (AppUser listener : follows.findActiveListenersByCreatorId(creatorId)) {
      send(listener, "NEW_POLL", channelName + " vừa đăng bình chọn",
          "Bình chọn mới từ " + channelName + ": " + question,
          Map.of("pollId", poll.getPollId(), "creatorId", creatorId));
    }
  }

  /** Notify a Creator when a Listener answers, changes or withdraws a vote. */
  public void pollResponse(Poll poll, AppUser listener, boolean changed,
      boolean withdrawn) {
    if (poll == null || listener == null || poll.getProducerProfile() == null) return;
    AppUser creator = poll.getProducerProfile().getUser();
    if (creator == null || creator.getUserId() == null) return;
    String action = withdrawn ? " đã rút bình chọn" : changed
        ? " đã thay đổi lựa chọn trong bình chọn"
        : " đã trả lời bình chọn";
    String question = poll.getQuestion();
    send(creator, "POLL_RESPONSE", listener.getDisplayName() + action,
        listener.getDisplayName() + action + ": " + question,
        Map.of("pollId", poll.getPollId(), "creatorId",
            creator.getUserId(), "listenerId", listener.getUserId()));
  }

  private void send(AppUser recipient, String type, String title, String message,
      Map<String, UUID> payload) {
    if (!Boolean.TRUE.equals(recipient.getIsActive())) return;
    Notification notification = new Notification();
    notification.setUser(recipient);
    notification.setNotificationType(type);
    notification.setTitle(title.length() > 200 ? title.substring(0, 197) + "..." : title);
    notification.setMessage(message);
    notification.setPayload(mapper.valueToTree(payload));
    notification.setIsRead(false);
    realtime.publish(notifications.save(notification));
  }
}
