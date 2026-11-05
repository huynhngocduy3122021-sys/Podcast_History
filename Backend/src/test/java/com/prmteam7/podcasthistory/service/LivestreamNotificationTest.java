package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

import com.prmteam7.podcasthistory.config.PackageFeatures;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import tools.jackson.databind.ObjectMapper;

class LivestreamNotificationTest {
  @Test
  void sendsOneNotificationToEachFollowerOrActiveMember() {
    NotificationRepository notifications = mock(NotificationRepository.class);
    FollowRepository follows = mock(FollowRepository.class);
    SubscriptionRepository subscriptions = mock(SubscriptionRepository.class);
    NotificationRealtimePublisher realtime = mock(NotificationRealtimePublisher.class);
    AudienceNotificationService service = new AudienceNotificationService(notifications, follows,
        subscriptions, mock(PackageFeatures.class), new ObjectMapper(), realtime);
    AppUser followerAndMember = listener();
    AppUser memberOnly = listener();
    Livestream live = live();
    UUID creatorId = live.getProducerProfile().getProducerProfileId();
    when(follows.findActiveListenersByCreatorId(creatorId)).thenReturn(List.of(followerAndMember));
    when(subscriptions.findActiveChannelListeners(eq(creatorId), any(Instant.class)))
        .thenReturn(List.of(followerAndMember, memberOnly));
    when(notifications.save(any(Notification.class))).thenAnswer(call -> call.getArgument(0));

    service.newLivestream(live);

    ArgumentCaptor<Notification> saved = ArgumentCaptor.forClass(Notification.class);
    verify(notifications, times(2)).save(saved.capture());
    verify(realtime, times(2)).publish(any(Notification.class));
    assertTrue(saved.getAllValues().stream().allMatch(n -> "LIVESTREAM_STARTED".equals(n.getNotificationType())));
    assertTrue(saved.getAllValues().stream().anyMatch(n -> n.getUser().getUserId().equals(followerAndMember.getUserId())));
    assertTrue(saved.getAllValues().stream().anyMatch(n -> n.getUser().getUserId().equals(memberOnly.getUserId())));
    assertEquals(live.getLivestreamId().toString(),
        saved.getAllValues().get(0).getPayload().get("livestreamId").asText());
  }

  @Test
  void restartingAlreadyLiveStreamDoesNotNotifyAgain() {
    LivestreamRepository livestreams = mock(LivestreamRepository.class);
    ProducerProfileRepository creators = mock(ProducerProfileRepository.class);
    AgoraRtcTokenService agora = mock(AgoraRtcTokenService.class);
    RealtimeEventPublisher realtime = mock(RealtimeEventPublisher.class);
    AudienceNotificationService audience = mock(AudienceNotificationService.class);
    LivestreamService service = new LivestreamService(livestreams, creators,
        mock(AppUserRepository.class), agora, mock(AgoraChatTokenService.class), realtime, audience,
        mock(ReportRepository.class));
    Livestream live = live();
    live.setStatus("DRAFT");
    AppUser creator = live.getProducerProfile().getUser();
    when(creators.findByUserIdForUpdate(creator.getUserId()))
        .thenReturn(Optional.of(live.getProducerProfile()));
    when(livestreams.findById(live.getLivestreamId())).thenReturn(Optional.of(live));
    when(livestreams.save(any(Livestream.class))).thenAnswer(call -> call.getArgument(0));

    service.start(creator.getUserId(), live.getLivestreamId());
    service.start(creator.getUserId(), live.getLivestreamId());

    verify(audience, times(1)).newLivestream(live);
    verify(realtime, times(1)).publishTopic(eq("/topic/livestreams"),
        eq("LIVESTREAM_UPDATED"), any());
  }

  private AppUser listener() {
    AppUser user = new AppUser();
    user.setUserId(UUID.randomUUID());
    user.setIsActive(true);
    return user;
  }

  private Livestream live() {
    AppUser creator = new AppUser();
    creator.setUserId(UUID.randomUUID());
    creator.setIsActive(true);
    Role role = new Role();
    role.setRoleCode("CREATOR");
    creator.setRole(role);
    ProducerProfile profile = new ProducerProfile();
    profile.setProducerProfileId(UUID.randomUUID());
    profile.setUser(creator);
    profile.setVerificationStatus("APPROVED");
    profile.setChannelName("Kênh thử nghiệm");
    Livestream live = new Livestream();
    live.setLivestreamId(UUID.randomUUID());
    live.setProducerProfile(profile);
    live.setTitle("Live hôm nay");
    live.setStatus("LIVE");
    return live;
  }
}
