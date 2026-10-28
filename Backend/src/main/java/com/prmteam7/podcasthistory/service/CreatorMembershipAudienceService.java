package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.exception.ResourceForbiddenException;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.exception.InvalidFlowRequestException;
import com.prmteam7.podcasthistory.model.Subscription;
import com.prmteam7.podcasthistory.repository.ProducerProfileRepository;
import com.prmteam7.podcasthistory.repository.SubscriptionRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CreatorMembershipAudienceService {
  private static final Set<String> STATUSES = Set.of("ACTIVE", "PENDING", "EXPIRED", "CANCELLED");
  private final ProducerProfileRepository creators;
  private final SubscriptionRepository subscriptions;

  public CreatorMembershipAudienceService(ProducerProfileRepository creators,
      SubscriptionRepository subscriptions) {
    this.creators = creators;
    this.subscriptions = subscriptions;
  }

  @Transactional(readOnly = true)
  public Page<MemberItem> list(UUID creatorUserId, String status, int page, int size) {
    var creator = creators.findByUser_UserId(creatorUserId)
        .orElseThrow(() -> new ResourceNotFoundException("Tài khoản chưa có kênh CC."));
    if (!"APPROVED".equalsIgnoreCase(creator.getVerificationStatus())
        || !Boolean.TRUE.equals(creator.getUser().getIsActive())
        || creator.getUser().getRole() == null
        || !"CREATOR".equalsIgnoreCase(creator.getUser().getRole().getRoleCode())) {
      throw new ResourceForbiddenException("Kênh CC chưa được duyệt hoặc tài khoản không hoạt động.");
    }
    String filter = status == null || status.isBlank() ? "ACTIVE" : status.trim().toUpperCase(Locale.ROOT);
    if (!STATUSES.contains(filter)) {
      throw new InvalidFlowRequestException("status phải là ACTIVE, PENDING, EXPIRED hoặc CANCELLED.");
    }
    var pageable = PageRequest.of(Math.max(0, page), Math.min(100, Math.max(1, size)),
        Sort.by(Sort.Direction.DESC, "createdAt"));
    return subscriptions.findChannelMembers(creator.getProducerProfileId(), filter, Instant.now(), pageable)
        .map(this::view);
  }

  private MemberItem view(Subscription s) {
    var member = s.getUser();
    var plan = s.getMembershipPlan();
    return new MemberItem(s.getSubscriptionId(), member.getUserId(), member.getUsername(),
        member.getDisplayName(), member.getAvatarUrl(), plan.getMembershipPlanId(),
        plan.getName(), plan.getPrice(), plan.getCurrency(), s.getStatus(),
        s.getStartAt(), s.getEndAt());
  }

  public record MemberItem(UUID subscriptionId, UUID listenerId, String username,
      String displayName, String avatarUrl, UUID membershipPlanId, String planName,
      BigDecimal price, String currency, String status, Instant startAt, Instant endAt) {}
}
