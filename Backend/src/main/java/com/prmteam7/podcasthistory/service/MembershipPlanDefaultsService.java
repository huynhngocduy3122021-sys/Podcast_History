package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.enums.MembershipPlanTemplateCode;
import com.prmteam7.podcasthistory.model.MembershipPlan;
import com.prmteam7.podcasthistory.model.ProducerProfile;
import com.prmteam7.podcasthistory.repository.MembershipPlanRepository;
import com.prmteam7.podcasthistory.repository.ProducerProfileRepository;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Provisions the single membership template for approved channels.
 *
 * <p>This is deliberately idempotent: it can run at startup and after a creator is approved
 * without changing an existing plan or duplicating a plan.
 */
@Service
public class MembershipPlanDefaultsService {
  private final MembershipPlanRepository plans;
  private final ProducerProfileRepository creators;

  public MembershipPlanDefaultsService(
      MembershipPlanRepository plans, ProducerProfileRepository creators) {
    this.plans = plans;
    this.creators = creators;
  }

  @Transactional
  public int provisionApprovedChannels() {
    AtomicInteger created = new AtomicInteger();
    creators
        .findAllByVerificationStatusIgnoreCaseOrderByChannelNameAsc("APPROVED")
        .forEach(creator -> created.addAndGet(provisionFor(creator)));
    return created.get();
  }

  @Transactional
  public int provisionFor(ProducerProfile creator) {
    if (creator == null
        || !"APPROVED".equalsIgnoreCase(creator.getVerificationStatus())
        || creator.getUser() == null
        || !Boolean.TRUE.equals(creator.getUser().getIsActive())) {
      return 0;
    }

    MembershipPlanTemplateCode template = MembershipPlanTemplateCode.DEFAULT;
    List<MembershipPlan> channelPlans =
        plans.findAllByProducerProfile_ProducerProfileIdOrderByCreatedAtDesc(
            creator.getProducerProfileId());

    MembershipPlan selected = channelPlans.stream()
        .filter(plan -> template.name().equalsIgnoreCase(plan.getTemplateCode())
            && "ACTIVE".equalsIgnoreCase(plan.getStatus()))
        .findFirst()
        .orElseGet(() -> channelPlans.stream()
            .filter(plan -> MembershipPlanTemplateCode.isLegacyCode(plan.getTemplateCode())
                && "ACTIVE".equalsIgnoreCase(plan.getStatus()))
            .findFirst()
            .orElseGet(() -> channelPlans.stream()
                .filter(plan -> template.name().equalsIgnoreCase(plan.getTemplateCode()))
                .findFirst()
                .orElseGet(() -> channelPlans.stream()
                    .filter(plan -> MembershipPlanTemplateCode.isLegacyCode(plan.getTemplateCode()))
                    .findFirst()
                    .orElse(null))));

    int created = 0;
    if (selected == null) {
      selected = new MembershipPlan();
      selected.setProducerProfile(creator);
      selected.setTemplateCode(template.name());
      selected.setName(template.getDisplayName());
      selected.setDescription(MembershipPlanTemplateCode.PRIVATE_VIDEO_BENEFIT);
      selected.setPrice(template.getPrice());
      selected.setCurrency(MembershipPlanTemplateCode.CURRENCY);
      selected.setDurationDays(MembershipPlanTemplateCode.DEFAULT_DURATION_DAYS);
      selected.setStatus("INACTIVE");
      channelPlans.add(selected);
      created++;
    } else if (!template.name().equalsIgnoreCase(selected.getTemplateCode())) {
      // Reuse the legacy row so existing subscriptions and payment history keep their FK.
      selected.setTemplateCode(template.name());
      selected.setName(template.getDisplayName());
      selected.setDescription(MembershipPlanTemplateCode.PRIVATE_VIDEO_BENEFIT);
    }

    // Retire the old 25K/50K/75K template rows. They remain in the database for historical
    // subscriptions, but are no longer selectable or visible as active channel plans.
    for (MembershipPlan plan : channelPlans) {
      if (plan != selected && (MembershipPlanTemplateCode.isLegacyCode(plan.getTemplateCode())
          || template.name().equalsIgnoreCase(plan.getTemplateCode()))) {
        plan.setStatus("INACTIVE");
      }
    }
    plans.saveAll(channelPlans);
    return created;
  }
}
