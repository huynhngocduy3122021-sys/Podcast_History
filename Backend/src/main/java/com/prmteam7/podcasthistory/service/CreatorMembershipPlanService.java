package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.enums.MembershipPlanTemplateCode;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.exception.ResourceForbiddenException;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.model.MembershipPlan;
import com.prmteam7.podcasthistory.model.ProducerProfile;
import com.prmteam7.podcasthistory.repository.MembershipPlanRepository;
import com.prmteam7.podcasthistory.repository.ProducerProfileRepository;
import java.math.BigDecimal;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class CreatorMembershipPlanService {
  private final MembershipPlanRepository plans;
  private final ProducerProfileRepository creators;
  private final MembershipPlanDefaultsService defaults;

  public CreatorMembershipPlanService(MembershipPlanRepository plans,
      ProducerProfileRepository creators, MembershipPlanDefaultsService defaults) {
    this.plans = plans;
    this.creators = creators;
    this.defaults = defaults;
  }

  public List<PlanTemplate> templates(UUID userId) {
    approved(userId, false);
    return Arrays.stream(MembershipPlanTemplateCode.values())
        .map(t -> new PlanTemplate(t.name(), t.getDisplayName(), t.getPrice(),
            MembershipPlanTemplateCode.CURRENCY, MembershipPlanTemplateCode.DEFAULT_DURATION_DAYS,
            MembershipPlanTemplateCode.PRIVATE_VIDEO_BENEFIT))
        .toList();
  }

  public List<ChannelPlan> myPlans(UUID userId) {
    var profile = approved(userId, false);
    // Only the currently sellable plan is returned. Historical inactive rows are retained for
    // subscriptions/payments but must not appear as additional selectable packages.
    return plans.findAllByProducerProfile_ProducerProfileIdAndStatusIgnoreCaseOrderByPriceAsc(
        profile.getProducerProfileId(), "ACTIVE").stream().map(this::view).toList();
  }

  @Transactional
  public ChannelPlan select(UUID userId, String code) {
    var template = template(code);
    var profile = approved(userId, true);
    defaults.provisionFor(profile);
    var channelPlans = plans.findAllByProducerProfile_ProducerProfileIdOrderByCreatedAtDesc(
        profile.getProducerProfileId());
    MembershipPlan selected = null;
    for (var plan : channelPlans) {
      // A channel may sell exactly one membership plan. Deactivate every other
      // row, including legacy/custom plans without a template code.
      if (template.name().equals(plan.getTemplateCode()) && selected == null) {
        selected = plan;
        plan.setStatus("ACTIVE");
      } else {
        plan.setStatus("INACTIVE");
      }
    }
    if (selected == null) throw new ResourceNotFoundException("Không tìm thấy gói mẫu của kênh.");
    plans.saveAll(channelPlans);
    return view(selected);
  }

  @Transactional
  public ChannelPlan updatePrice(UUID userId, UUID planId, BigDecimal price) {
    var profile = approved(userId, true);
    var plan = plans.lockById(planId)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy gói membership."));
    if (!plan.getProducerProfile().getProducerProfileId().equals(profile.getProducerProfileId()))
      throw new ResourceForbiddenException("Bạn không sở hữu gói membership này.");
    if (plan.getTemplateCode() == null || !"ACTIVE".equals(plan.getStatus()))
      throw new ResourceConflictException("Chỉ được đổi giá gói mẫu đang được chọn.");
    if (price == null || price.scale() > 0 || price.compareTo(new BigDecimal("1000")) < 0
        || price.compareTo(new BigDecimal("9999999999")) > 0)
      throw new ResourceConflictException("Giá phải là số VND nguyên từ 1.000 đến 9.999.999.999.");
    if (plan.getPrice().compareTo(price) == 0) return view(plan);

    // Keep the old plan row for subscriptions and payments already linked to it.
    plan.setStatus("INACTIVE");
    plans.save(plan);
    var replacement = new MembershipPlan();
    replacement.setProducerProfile(profile);
    replacement.setTemplateCode(plan.getTemplateCode());
    replacement.setName(plan.getName());
    replacement.setDescription(plan.getDescription());
    replacement.setPrice(price);
    replacement.setCurrency(plan.getCurrency());
    replacement.setDurationDays(plan.getDurationDays());
    replacement.setStatus("ACTIVE");
    return view(plans.save(replacement));
  }

  private MembershipPlanTemplateCode template(String code) {
    if (code == null || code.isBlank()) {
      throw new ResourceNotFoundException("Không tìm thấy gói mẫu.");
    }
    String normalized = code.trim().toUpperCase(java.util.Locale.ROOT);
    // Accept old client links during migration, but map them to the only current template.
    if (MembershipPlanTemplateCode.isLegacyCode(normalized)) {
      return MembershipPlanTemplateCode.DEFAULT;
    }
    try {
      return MembershipPlanTemplateCode.valueOf(normalized);
    } catch (IllegalArgumentException exception) {
      throw new ResourceNotFoundException("Không tìm thấy gói mẫu.");
    }
  }

  private ProducerProfile approved(UUID userId, boolean lock) {
    var profile = (lock ? creators.findByUserIdForUpdate(userId) : creators.findByUser_UserId(userId))
        .orElseThrow(() -> new ResourceNotFoundException("Tài khoản chưa có kênh CC."));
    if (!"APPROVED".equalsIgnoreCase(profile.getVerificationStatus())
        || !Boolean.TRUE.equals(profile.getUser().getIsActive())
        || profile.getUser().getRole() == null
        || !"CREATOR".equalsIgnoreCase(profile.getUser().getRole().getRoleCode()))
      throw new ResourceForbiddenException("Kênh CC chưa được duyệt hoặc tài khoản không hoạt động.");
    return profile;
  }

  private ChannelPlan view(MembershipPlan p) {
    return new ChannelPlan(p.getMembershipPlanId(), p.getProducerProfile().getProducerProfileId(),
        p.getTemplateCode(), p.getName(), p.getDescription(), p.getPrice(),
        p.getCurrency(), p.getDurationDays(), p.getStatus());
  }

  public record PlanTemplate(String code, String name, BigDecimal suggestedPrice, String currency,
      int durationDays, String benefit) {}

  public record ChannelPlan(UUID planId, UUID creatorId, String templateCode, String name,
      String description, BigDecimal price, String currency, int durationDays, String status) {}
}
