package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.request.LivestreamRequests.Create;
import com.prmteam7.podcasthistory.dto.response.LivestreamResponses.AgoraJoin;
import com.prmteam7.podcasthistory.dto.response.LivestreamResponses.ChatJoin;
import com.prmteam7.podcasthistory.dto.response.LivestreamResponses.Item;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.exception.ResourceForbiddenException;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.Livestream;
import com.prmteam7.podcasthistory.model.ProducerProfile;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.LivestreamRepository;
import com.prmteam7.podcasthistory.repository.ProducerProfileRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class LivestreamService {
  private final LivestreamRepository livestreams;
  private final ProducerProfileRepository creators;
  private final AppUserRepository users;
  private final AgoraRtcTokenService agora;
  private final AgoraChatTokenService chat;
  private final RealtimeEventPublisher realtime;

  public LivestreamService(LivestreamRepository livestreams, ProducerProfileRepository creators,
      AppUserRepository users, AgoraRtcTokenService agora, AgoraChatTokenService chat,
      RealtimeEventPublisher realtime) {
    this.livestreams = livestreams;
    this.creators = creators;
    this.users = users;
    this.agora = agora;
    this.chat = chat;
    this.realtime = realtime;
  }

  @Transactional
  public Item create(UUID userId, Create request) {
    ProducerProfile creator = approvedCreator(userId, false);
    Livestream live = new Livestream();
    live.setUser(creator.getUser());
    live.setProducerProfile(creator);
    live.setTitle(request.title().trim());
    live.setDescription(blankToNull(request.description()));
    live.setStreamProvider("AGORA");
    live.setStreamReference("live_" + UUID.randomUUID().toString().replace("-", ""));
    live.setStatus("DRAFT");
    live.setScheduledAt(request.scheduledAt());
    return item(livestreams.save(live));
  }

  @Transactional(readOnly = true)
  public List<Item> mine(UUID userId) {
    ProducerProfile creator = approvedCreator(userId, false);
    return livestreams.findAllByProducerProfile_ProducerProfileIdOrderByCreatedAtDesc(
        creator.getProducerProfileId()).stream().map(this::item).toList();
  }

  @Transactional(readOnly = true)
  public Item own(UUID userId, UUID livestreamId) {
    return item(owned(userId, livestreamId));
  }

  @Transactional
  public AgoraJoin start(UUID userId, UUID livestreamId) {
    ProducerProfile creator = approvedCreator(userId, true);
    Livestream live = owned(creator, livestreamId);
    if ("LIVE".equals(live.getStatus())) {
      return agora.issue(live, userId, true);
    }
    if (!"DRAFT".equals(live.getStatus())) {
      throw new ResourceConflictException("Chỉ có thể bắt đầu livestream đang ở trạng thái DRAFT.");
    }
    if (livestreams.existsByProducerProfile_ProducerProfileIdAndStatusIgnoreCase(
        creator.getProducerProfileId(), "LIVE")) {
      throw new ResourceConflictException("Kênh đã có một livestream đang phát.");
    }
    agora.requireConfigured();
    live.setStatus("LIVE");
    live.setStartedAt(Instant.now());
    live.setEndedAt(null);
    Livestream saved = livestreams.save(live);
    realtime.publishTopic("/topic/livestreams", "LIVESTREAM_UPDATED", item(saved));
    return agora.issue(saved, userId, true);
  }

  @Transactional(readOnly = true)
  public AgoraJoin hostToken(UUID userId, UUID livestreamId) {
    Livestream live = owned(userId, livestreamId);
    requireLive(live);
    return agora.issue(live, userId, true);
  }

  @Transactional(readOnly = true)
  public ChatJoin hostChatToken(UUID userId, UUID livestreamId) {
    Livestream live = owned(userId, livestreamId);
    requireLive(live);
    return chat.issue(live, live.getUser());
  }

  @Transactional
  public Item end(UUID userId, UUID livestreamId) {
    ProducerProfile creator = approvedCreator(userId, true);
    Livestream live = owned(creator, livestreamId);
    requireLive(live);
    live.setStatus("ENDED");
    live.setEndedAt(Instant.now());
    Livestream saved = livestreams.save(live);
    realtime.publishTopic("/topic/livestreams", "LIVESTREAM_UPDATED", item(saved));
    return item(saved);
  }

  @Transactional(readOnly = true)
  public Page<Item> live(int page, int size) {
    return livestreams
        .findAllByStatusIgnoreCaseAndProducerProfile_VerificationStatusIgnoreCaseAndProducerProfile_User_IsActiveTrueOrderByStartedAtDesc(
            "LIVE", "APPROVED", PageRequest.of(Math.max(page, 0), Math.min(100, Math.max(size, 1))))
        .map(this::item);
  }

  @Transactional(readOnly = true)
  public Item visible(UUID livestreamId) {
    return item(visibleLive(livestreamId));
  }

  @Transactional(readOnly = true)
  public AgoraJoin join(UUID userId, UUID livestreamId) {
    AppUser listener = activeListener(userId);
    return agora.issue(visibleLive(livestreamId), userId, false);
  }

  @Transactional(readOnly = true)
  public ChatJoin listenerChatToken(UUID userId, UUID livestreamId) {
    AppUser listener = activeListener(userId);
    return chat.issue(visibleLive(livestreamId), listener);
  }

  private AppUser activeListener(UUID userId) {
    AppUser listener = users.findByUserId(userId)
        .filter(u -> Boolean.TRUE.equals(u.getIsActive()))
        .orElseThrow(() -> new ResourceForbiddenException("Tài khoản không hoạt động."));
    if (!"LISTENER".equals(listener.getRole().getRoleCode())) {
      throw new ResourceForbiddenException("Chỉ Listener được tham gia với quyền người xem.");
    }
    return listener;
  }

  private ProducerProfile approvedCreator(UUID userId, boolean lock) {
    ProducerProfile profile = (lock ? creators.findByUserIdForUpdate(userId) : creators.findByUser_UserId(userId))
        .orElseThrow(() -> new ResourceForbiddenException("Bạn chưa có kênh Creator."));
    if (!Boolean.TRUE.equals(profile.getUser().getIsActive())
        || !"CREATOR".equals(profile.getUser().getRole().getRoleCode())
        || !"APPROVED".equalsIgnoreCase(profile.getVerificationStatus())) {
      throw new ResourceForbiddenException("Kênh Creator chưa được duyệt hoặc tài khoản không hoạt động.");
    }
    return profile;
  }

  private Livestream owned(UUID userId, UUID id) {
    return owned(approvedCreator(userId, false), id);
  }

  private Livestream owned(ProducerProfile creator, UUID id) {
    Livestream live = livestreams.findById(id)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy livestream."));
    if (!live.getProducerProfile().getProducerProfileId().equals(creator.getProducerProfileId())) {
      throw new ResourceNotFoundException("Không tìm thấy livestream thuộc kênh của bạn.");
    }
    return live;
  }

  private Livestream visibleLive(UUID id) {
    Livestream live = livestreams.findById(id)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy livestream đang phát."));
    requireLive(live);
    ProducerProfile creator = live.getProducerProfile();
    if (!"APPROVED".equalsIgnoreCase(creator.getVerificationStatus())
        || !Boolean.TRUE.equals(creator.getUser().getIsActive())) {
      throw new ResourceNotFoundException("Không tìm thấy livestream đang phát.");
    }
    return live;
  }

  private void requireLive(Livestream live) {
    if (!"LIVE".equalsIgnoreCase(live.getStatus())) {
      throw new ResourceConflictException("Livestream hiện không phát trực tiếp.");
    }
  }

  private Item item(Livestream live) {
    return new Item(live.getLivestreamId(), live.getProducerProfile().getProducerProfileId(),
        live.getProducerProfile().getChannelName(), live.getTitle(), live.getDescription(),
        live.getStatus(), live.getScheduledAt(), live.getStartedAt(), live.getEndedAt(),
        live.getCreatedAt(), live.getUpdatedAt());
  }

  private String blankToNull(String value) {
    return value == null || value.isBlank() ? null : value.trim();
  }
}
