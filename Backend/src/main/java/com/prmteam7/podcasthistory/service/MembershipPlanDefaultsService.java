package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.enums.MembershipPlanTemplateCode;
import com.prmteam7.podcasthistory.model.MembershipPlan;
import com.prmteam7.podcasthistory.model.ProducerProfile;
import com.prmteam7.podcasthistory.repository.MembershipPlanRepository;
import com.prmteam7.podcasthistory.repository.ProducerProfileRepository;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Provisions the fixed membership tiers for approved channels.
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

    int created = 0;
    for (MembershipPlanTemplateCode template : MembershipPlanTemplateCode.values()) {
      if (plans.existsByProducerProfile_ProducerProfileIdAndTemplateCode(
          creator.getProducerProfileId(), template.name())) {
        continue;
      }

      MembershipPlan plan = new MembershipPlan();
      plan.setProducerProfile(creator);
      plan.setTemplateCode(template.name());
      plan.setName(template.getDisplayName());
      plan.setDescription(MembershipPlanTemplateCode.PRIVATE_VIDEO_BENEFIT);
      plan.setPrice(template.getPrice());
      plan.setCurrency(MembershipPlanTemplateCode.CURRENCY);
      plan.setDurationDays(MembershipPlanTemplateCode.DEFAULT_DURATION_DAYS);
      plan.setStatus("INACTIVE");
      plans.save(plan);
      created++;
    }
    return created;
  }
}
