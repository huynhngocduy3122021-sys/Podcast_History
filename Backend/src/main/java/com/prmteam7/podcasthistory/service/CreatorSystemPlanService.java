package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.request.CreatorSystemPlanWrite;
import com.prmteam7.podcasthistory.config.PackageFeatures;
import com.prmteam7.podcasthistory.dto.response.CreatorSystemPlanView;
import com.prmteam7.podcasthistory.dto.response.CreatorSystemSubscriptionView;
import com.prmteam7.podcasthistory.dto.response.CheckoutPaymentView;
import com.prmteam7.podcasthistory.exception.*;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class CreatorSystemPlanService {
  private final CreatorSystemPlanRepository plans;
  private final CreatorSystemSubscriptionRepository subscriptions;
  private final ProducerProfileRepository creators;
  private final PodcastRepository podcasts;
  private final AdminSupportService adminSupport;
  private final PackageFeatures packageFeatures;
  private final CheckoutPaymentRepository checkouts;
  private final SepayService sepay;

  public CreatorSystemPlanService(
      CreatorSystemPlanRepository plans,
      CreatorSystemSubscriptionRepository subscriptions,
      ProducerProfileRepository creators,
      PodcastRepository podcasts,
      AdminSupportService adminSupport,
      PackageFeatures packageFeatures, CheckoutPaymentRepository checkouts, SepayService sepay) {
    this.plans = plans;
    this.subscriptions = subscriptions;
    this.creators = creators;
    this.podcasts = podcasts;
    this.adminSupport = adminSupport;
    this.packageFeatures = packageFeatures;
    this.checkouts = checkouts;
    this.sepay = sepay;
  }

  public List<CreatorSystemPlanView> available() {
    if (!packageFeatures.creatorPlansEnabled()) return List.of();
    return plans.findAllByStatusIgnoreCaseOrderByPriceAsc("ACTIVE").stream().map(this::view).toList();
  }

  public List<CreatorSystemPlanView> adminList(UUID actor) {
    adminSupport.actor(actor, true);
    return plans.findAllByOrderByPriceAsc().stream().map(this::view).toList();
  }

  public CreatorSystemPlanView adminGet(UUID actor, UUID id) {
    adminSupport.actor(actor, true);
    return view(requirePlan(id));
  }

  @Transactional
  public CreatorSystemPlanView create(UUID actor, CreatorSystemPlanWrite body) {
    var admin = adminSupport.actor(actor, true);
    var code = body.code().trim().toUpperCase(Locale.ROOT);
    if (plans.existsByCodeIgnoreCase(code)) throw new ResourceConflictException("Mã gói CC đã tồn tại.");
    var plan = new CreatorSystemPlan();
    plan.setCode(code);
    apply(plan, body);
    plan = plans.saveAndFlush(plan);
    adminSupport.audit(admin, "CREATE_CREATOR_PLAN", "CREATOR_PLAN", plan.getPlanId(), code);
    return view(plan);
  }

  @Transactional
  public CreatorSystemPlanView update(UUID actor, UUID id, CreatorSystemPlanWrite body) {
    var admin = adminSupport.actor(actor, true);
    var plan = plans.lockById(id).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy gói CC."));
    if (!plan.getCode().equalsIgnoreCase(body.code()))
      throw new ResourceConflictException("Không thể đổi mã của gói hiện có.");
    apply(plan, body);
    adminSupport.audit(admin, "UPDATE_CREATOR_PLAN", "CREATOR_PLAN", id, plan.getCode());
    return view(plans.save(plan));
  }

  @Transactional
  public CreatorSystemPlanView delete(UUID actor, UUID id) {
    var admin = adminSupport.actor(actor, true);
    var plan = plans.lockById(id).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy gói CC."));
    if ("FREE".equals(plan.getCode()))
      throw new ResourceConflictException("Không thể xóa gói FREE mặc định.");
    plan.setStatus("INACTIVE");
    adminSupport.audit(admin, "DEACTIVATE_CREATOR_PLAN", "CREATOR_PLAN", id, plan.getCode());
    return view(plans.save(plan));
  }

  public CreatorSystemSubscriptionView current(UUID userId) {
    var profile = approvedCreator(userId, false);
    if (!packageFeatures.creatorPlansEnabled()) {
      var used = podcasts.countByProducerProfile_ProducerProfileIdAndMediaUrlIsNotNull(profile.getProducerProfileId());
      return new CreatorSystemSubscriptionView("DISABLED", null, "Gói đang tạm tắt",
          null, null, null, used, null, false, null, null, null, null, List.of());
    }
    var now = Instant.now();
    var active = activeSubscription(profile.getProducerProfileId(), now);
    var plan = active.map(CreatorSystemSubscription::getPlan).orElseGet(this::freePlan);
    var benefits = active.map(CreatorSystemSubscription::getBenefits).orElseGet(plan::getBenefits);
    var used = podcasts.countByProducerProfile_ProducerProfileIdAndMediaUrlIsNotNull(profile.getProducerProfileId());
    return subscriptionView(plan, active.orElse(null), benefits, used);
  }

  @Transactional
  public CheckoutPaymentView subscribe(UUID userId, UUID planId) {
    packageFeatures.requireCreatorPlans();
    var profile = approvedCreator(userId, true);
    var now = Instant.now();
    if (activeSubscription(profile.getProducerProfileId(), now).isPresent())
      throw new ResourceConflictException("Gói CC hiện tại còn hiệu lực; hãy đăng ký sau khi hết hạn.");
    checkouts.findFirstByCreatorSubscription_ProducerProfile_ProducerProfileIdAndStatusOrderByCreatedAtDesc(
        profile.getProducerProfileId(), "PENDING")
        .ifPresent(checkout -> sepay.getCheckoutStatus(userId, checkout.getCheckoutId()));
    if (subscriptions.existsByProducerProfile_ProducerProfileIdAndPaymentStatus(profile.getProducerProfileId(), "PENDING"))
      throw new ResourceConflictException("Đã có thanh toán gói CC đang chờ.");
    checkouts.findFirstByCreatorSubscription_ProducerProfile_ProducerProfileIdAndStatusOrderByCreatedAtDesc(
        profile.getProducerProfileId(), "EXPIRED")
        .filter(checkout -> checkout.getCreatedAt().plus(35, ChronoUnit.MINUTES).isAfter(now))
        .ifPresent(checkout -> { throw new ResourceConflictException(
            "Checkout vừa hết hạn; vui lòng đợi thêm tối đa 5 phút trước khi đăng ký lại."); });
    var plan = requirePlan(planId);
    if (!"ACTIVE".equals(plan.getStatus()) || plan.getPrice().signum() <= 0)
      throw new ResourceConflictException("Chỉ có thể đăng ký gói trả phí đang hoạt động.");
    if (!"VND".equalsIgnoreCase(plan.getCurrency().trim()))
      throw new InvalidFlowRequestException("SePay chỉ hỗ trợ thanh toán gói bằng VND.");
    String paymentCode = sepay.generatePaymentCode();
    String qrImageUrl = sepay.createQrImageUrl(plan.getPrice(), paymentCode);
    var subscription = new CreatorSystemSubscription();
    subscription.setProducerProfile(profile);
    subscription.setPlan(plan);
    subscription.setStartAt(now);
    subscription.setEndAt(now.plus(plan.getDurationDays(), ChronoUnit.DAYS));
    subscription.setAmount(plan.getPrice());
    subscription.setCurrency(plan.getCurrency());
    subscription.setPaymentStatus("PENDING");
    subscription.setPaymentReference(paymentCode);
    subscription.setBenefits(new ArrayList<>(plan.getBenefits().stream()
        .map(b -> new CreatorSystemBenefit(b.getKey(), b.getValue(), b.getDescription()))
        .toList()));
    subscription = subscriptions.saveAndFlush(subscription);
    var checkout = new CheckoutPayment();
    checkout.setUser(profile.getUser());
    checkout.setCreatorSubscription(subscription);
    checkout.setPurpose("CREATOR_PLAN");
    checkout.setAmount(plan.getPrice());
    checkout.setCurrency(plan.getCurrency());
    checkout.setPaymentCode(paymentCode);
    checkout.setStatus("PENDING");
    checkout = checkouts.saveAndFlush(checkout);
    return new CheckoutPaymentView(checkout.getCheckoutId(), subscription.getSubscriptionId(),
        checkout.getPurpose(), paymentCode, qrImageUrl, checkout.getAmount(), checkout.getCurrency(),
        checkout.getStatus(), null, checkout.getCreatedAt().plus(30, ChronoUnit.MINUTES));
  }

  @Transactional
  public CheckoutPaymentView cancelPendingCheckout(UUID userId) {
    var profile = approvedCreator(userId, true);
    var pending = checkouts
        .findFirstByCreatorSubscription_ProducerProfile_ProducerProfileIdAndStatusOrderByCreatedAtDesc(
            profile.getProducerProfileId(), "PENDING")
        .orElseThrow(() -> new ResourceNotFoundException("Không có checkout gói CC đang chờ."));
    var checkout = checkouts.lockById(pending.getCheckoutId()).orElseThrow();
    if (!"PENDING".equals(checkout.getStatus()))
      throw new ResourceConflictException("Checkout đã được xử lý; vui lòng tải lại trạng thái.");
    var subscription = subscriptions.findById(checkout.getCreatorSubscription().getSubscriptionId())
        .orElseThrow();
    if (!"PENDING".equals(subscription.getPaymentStatus()))
      throw new ResourceConflictException("Gói CC đã được xử lý; vui lòng tải lại trạng thái.");
    checkout.setStatus("CANCELLED");
    subscription.setPaymentStatus("CANCELLED");
    subscriptions.save(subscription);
    checkouts.save(checkout);
    return new CheckoutPaymentView(checkout.getCheckoutId(), subscription.getSubscriptionId(),
        checkout.getPurpose(), checkout.getPaymentCode(), null,
        checkout.getAmount(), checkout.getCurrency(), checkout.getStatus(), checkout.getPaidAt(),
        checkout.getCreatedAt().plus(30, ChronoUnit.MINUTES));
  }

  @Transactional
  public void assertCanUpload(UUID creatorProfileId) {
    if (!packageFeatures.creatorPlansEnabled()) return;
    // Serialize upload quota checks for one channel while the media transaction is open.
    creators.findByIdForUpdate(creatorProfileId)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy kênh CC."));
    var active = activeSubscription(creatorProfileId, Instant.now());
    var benefits = active.map(CreatorSystemSubscription::getBenefits).orElseGet(() -> freePlan().getBenefits());
    Long limit = uploadLimit(benefits);
    if (limit != null && podcasts.countByProducerProfile_ProducerProfileIdAndMediaUrlIsNotNull(creatorProfileId) >= limit)
      throw new ResourceForbiddenException("Đã hết lượt đăng video/audio của gói CC hiện tại.");
  }

  private void apply(CreatorSystemPlan plan, CreatorSystemPlanWrite body) {
    var free = "FREE".equals(plan.getCode());
    if (free && (body.price().signum() != 0 || body.durationDays() != null || !"ACTIVE".equals(body.status())))
      throw new InvalidFlowRequestException("FREE phải có giá 0, không có thời hạn và luôn ACTIVE.");
    if (!free && (body.price().signum() <= 0 || body.durationDays() == null))
      throw new InvalidFlowRequestException("Gói trả phí cần giá dương và thời hạn từ 1 đến 3650 ngày.");
    var keys = new HashSet<String>();
    var benefits = new ArrayList<CreatorSystemBenefit>();
    for (var item : body.benefits()) {
      var key = item.key().trim().toUpperCase(Locale.ROOT);
      var value = item.value().trim();
      if (!keys.add(key)) throw new InvalidFlowRequestException("Mã quyền lợi bị trùng: " + key);
      if ("UPLOAD_LIMIT".equals(key) && !"unlimited".equalsIgnoreCase(value)) {
        try {
          if (Long.parseLong(value) < 0) throw new NumberFormatException();
        } catch (NumberFormatException exception) {
          throw new InvalidFlowRequestException("UPLOAD_LIMIT phải là số không âm hoặc unlimited.");
        }
      }
      if ("LIVESTREAM".equals(key) && !"true".equalsIgnoreCase(value) && !"false".equalsIgnoreCase(value))
        throw new InvalidFlowRequestException("LIVESTREAM phải là true hoặc false.");
      benefits.add(new CreatorSystemBenefit(key, value, item.description()));
    }
    plan.setName(body.name().trim());
    plan.setDescription(body.description());
    plan.setPrice(body.price());
    plan.setCurrency(body.currency());
    plan.setDurationDays(body.durationDays());
    plan.setStatus(body.status());
    plan.getBenefits().clear();
    plan.getBenefits().addAll(benefits);
  }

  private CreatorSystemPlan requirePlan(UUID id) {
    return plans.findById(id).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy gói CC."));
  }

  private CreatorSystemPlan freePlan() {
    return plans.findByCodeIgnoreCase("FREE")
        .orElseThrow(() -> new IllegalStateException("Chưa có gói FREE của CC."));
  }

  private ProducerProfile approvedCreator(UUID userId, boolean lock) {
    var profile = (lock ? creators.findByUserIdForUpdate(userId) : creators.findByUser_UserId(userId))
        .orElseThrow(() -> new ResourceNotFoundException("Tài khoản chưa có hồ sơ Creator."));
    if (!"APPROVED".equalsIgnoreCase(profile.getVerificationStatus())
        || !Boolean.TRUE.equals(profile.getUser().getIsActive()))
      throw new ResourceForbiddenException("Kênh CC chưa được duyệt hoặc đã bị khóa.");
    return profile;
  }

  private Optional<CreatorSystemSubscription> activeSubscription(UUID creatorId, Instant now) {
    return subscriptions
        .findTopByProducerProfile_ProducerProfileIdAndPaymentStatusAndStartAtLessThanEqualAndEndAtAfterOrderByEndAtDesc(
            creatorId, "SUCCEEDED", now, now);
  }

  private CreatorSystemPlanView view(CreatorSystemPlan plan) {
    return new CreatorSystemPlanView(plan.getPlanId(), plan.getCode(), plan.getName(), plan.getDescription(),
        plan.getPrice(), plan.getCurrency(), plan.getDurationDays(), plan.getStatus(),
        benefitsView(plan.getBenefits()));
  }

  private CreatorSystemSubscriptionView subscriptionView(
      CreatorSystemPlan plan, CreatorSystemSubscription subscription,
      List<CreatorSystemBenefit> benefits, long used) {
    var limit = uploadLimit(benefits);
    return new CreatorSystemSubscriptionView(plan.getCode(), plan.getPlanId(), plan.getName(),
        subscription == null ? null : subscription.getStartAt(),
        subscription == null ? null : subscription.getEndAt(),
        limit, used, limit == null ? null : Math.max(0L, limit - used),
        benefit(benefits, "LIVESTREAM").map(b -> Boolean.parseBoolean(b.getValue())).orElse(false),
        subscription == null ? null : subscription.getSubscriptionId(),
        subscription == null ? null : subscription.getAmount(),
        subscription == null ? null : subscription.getPaymentStatus(),
        subscription == null ? null : subscription.getPaymentReference(),
        benefitsView(benefits));
  }

  private static Long uploadLimit(List<CreatorSystemBenefit> benefits) {
    var value = benefit(benefits, "UPLOAD_LIMIT").map(CreatorSystemBenefit::getValue).orElse("0");
    return "unlimited".equalsIgnoreCase(value) ? null : Long.parseLong(value);
  }

  private static Optional<CreatorSystemBenefit> benefit(List<CreatorSystemBenefit> benefits, String key) {
    return benefits.stream().filter(b -> key.equals(b.getKey())).findFirst();
  }

  private static List<CreatorSystemPlanView.BenefitView> benefitsView(List<CreatorSystemBenefit> benefits) {
    return benefits.stream().map(b -> new CreatorSystemPlanView.BenefitView(
        b.getKey(), b.getValue(), b.getDescription())).toList();
  }
}
