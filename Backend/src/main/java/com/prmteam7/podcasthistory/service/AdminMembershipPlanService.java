package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.request.AdminRequests.MembershipPlanWrite;
import com.prmteam7.podcasthistory.dto.response.AdminResponses.PlanItem;
import com.prmteam7.podcasthistory.exception.*;
import com.prmteam7.podcasthistory.model.MembershipPlan;
import com.prmteam7.podcasthistory.repository.*;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class AdminMembershipPlanService {
  private final AdminSupportService support;
  private final MembershipPlanRepository plans;
  private final ProducerProfileRepository creators;
  private final SubscriptionRepository subscriptions;

  public AdminMembershipPlanService(
      AdminSupportService support,
      MembershipPlanRepository plans,
      ProducerProfileRepository creators,
      SubscriptionRepository subscriptions) {
    this.support = support;
    this.plans = plans;
    this.creators = creators;
    this.subscriptions = subscriptions;
  }

  public Page<PlanItem> list(UUID actor, UUID creatorId, int page, int size) {
    support.actor(actor, true);
    return plans
        .findAll(
            AdminSupportService.<MembershipPlan>status("ACTIVE")
                .and(
                    (r, q, c) ->
                        creatorId == null
                            ? c.conjunction()
                            : c.equal(
                                r.get("producerProfile").get("producerProfileId"), creatorId)),
            AdminSupportService.page(page, size))
        .map(this::item);
  }

  public PlanItem get(UUID actor, UUID id) {
    support.actor(actor, true);
    return item(
        plans.findById(id).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy gói.")));
  }

  @Transactional
  public PlanItem create(UUID actor, MembershipPlanWrite body) {
    var admin = support.actor(actor, true);
    var plan = new MembershipPlan();
    apply(plan, body);
    plan = plans.save(plan);
    support.audit(admin, "CREATE_PLAN", "MEMBERSHIP_PLAN", plan.getMembershipPlanId(), body.name());
    return item(plan);
  }

  @Transactional
  public PlanItem update(UUID actor, UUID id, MembershipPlanWrite body) {
    var admin = support.actor(actor, true);
    var plan = lock(id);
    if (!plan.getProducerProfile().getProducerProfileId().equals(body.creatorId()))
      throw new ResourceConflictException("Không chuyển gói sang kênh khác.");
    if (subscriptions.existsByMembershipPlan_MembershipPlanId(id)
        && (plan.getPrice().compareTo(body.price()) != 0
            || !plan.getCurrency().trim().equals(body.currency())
            || !plan.getDurationDays().equals(body.durationDays())))
      throw new ResourceConflictException(
          "Gói đã có checkout/subscription; hãy tạo gói mới nếu đổi giá, tiền tệ hoặc thời hạn.");
    apply(plan, body);
    support.audit(admin, "UPDATE_PLAN", "MEMBERSHIP_PLAN", id, body.name());
    return item(plans.save(plan));
  }

  @Transactional
  public PlanItem deactivate(UUID actor, UUID id, String note) {
    var admin = support.actor(actor, true);
    var plan = lock(id);
    plan.setStatus("INACTIVE");
    support.audit(admin, "DEACTIVATE_PLAN", "MEMBERSHIP_PLAN", id, note);
    return item(plans.save(plan));
  }

  private void apply(MembershipPlan plan, MembershipPlanWrite body) {
    var creator =
        creators
            .findById(body.creatorId())
            .filter(
                c ->
                    "APPROVED".equalsIgnoreCase(c.getVerificationStatus())
                        && Boolean.TRUE.equals(c.getUser().getIsActive()))
            .orElseThrow(
                () -> new ResourceConflictException("Kênh chưa được duyệt hoặc đã bị khóa."));
    plan.setProducerProfile(creator);
    plan.setName(body.name().trim());
    plan.setDescription(body.description());
    plan.setPrice(body.price());
    plan.setCurrency(body.currency());
    plan.setDurationDays(body.durationDays());
    plan.setStatus(body.status().name());
  }

  private MembershipPlan lock(UUID id) {
    return plans
        .lockById(id)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy gói."));
  }

  private PlanItem item(MembershipPlan p) {
    return new PlanItem(
        p.getMembershipPlanId(),
        p.getProducerProfile().getProducerProfileId(),
        p.getName(),
        p.getDescription(),
        p.getPrice(),
        p.getCurrency(),
        p.getDurationDays(),
        p.getStatus());
  }
}
