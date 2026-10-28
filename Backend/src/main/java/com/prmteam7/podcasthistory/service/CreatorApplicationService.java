package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.request.CreatorApplicationRequest;
import com.prmteam7.podcasthistory.dto.response.CreatorApplicationResponse;
import com.prmteam7.podcasthistory.enums.CreatorApplicationStatus;
import com.prmteam7.podcasthistory.enums.UserRole;
import com.prmteam7.podcasthistory.exception.CreatorApplicationConflictException;
import com.prmteam7.podcasthistory.exception.CreatorApplicationNotFoundException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.ProducerProfile;
import com.prmteam7.podcasthistory.model.Role;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.ProducerProfileRepository;
import com.prmteam7.podcasthistory.repository.RoleRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Creator applications are represented by Creator_profile rows with verification_status=PENDING; no
 * separate application table is required.
 */
@Service
public class CreatorApplicationService {

  private final ProducerProfileRepository producerProfileRepository;
  private final AppUserRepository appUserRepository;
  private final RoleRepository roleRepository;
  private final AdminSupportService support;
  private final MembershipPlanDefaultsService membershipPlanDefaults;

  public CreatorApplicationService(
      ProducerProfileRepository producerProfileRepository,
      AppUserRepository appUserRepository,
      RoleRepository roleRepository,
      AdminSupportService support,
      MembershipPlanDefaultsService membershipPlanDefaults) {
    this.producerProfileRepository = producerProfileRepository;
    this.appUserRepository = appUserRepository;
    this.roleRepository = roleRepository;
    this.support = support;
    this.membershipPlanDefaults = membershipPlanDefaults;
  }

  @Transactional(readOnly = true)
  public org.springframework.data.domain.Page<CreatorApplicationResponse> history(
      UUID actor, String status, int page, int size) {
    support.actor(actor, true);
    return producerProfileRepository
        .findAll(
            (r, q, c) ->
                status == null || status.isBlank()
                    ? c.conjunction()
                    : c.equal(
                        c.upper(r.get("verificationStatus")),
                        status.toUpperCase(java.util.Locale.ROOT)),
            AdminSupportService.page(page, size))
        .map(this::toResponse);
  }

  @Transactional(readOnly = true)
  public CreatorApplicationResponse detail(UUID actor, UUID id) {
    support.actor(actor, true);
    return toResponse(
        producerProfileRepository
            .findById(id)
            .orElseThrow(CreatorApplicationNotFoundException::new));
  }

  @Transactional
  public CreatorApplicationResponse submit(UUID applicantId, CreatorApplicationRequest request) {
    AppUser applicant = requireUser(applicantId);
    requireActive(applicant);
    if (!hasRole(applicant, UserRole.LISTENER)) {
      throw new CreatorApplicationConflictException(
          "Chỉ tài khoản Listener mới có thể đăng ký làm Creator.");
    }

    ProducerProfile profile =
        producerProfileRepository.findByUserIdForUpdate(applicantId).orElse(null);
    if (profile != null
        && !CreatorApplicationStatus.REJECTED
            .name()
            .equalsIgnoreCase(profile.getVerificationStatus())) {
      String message =
          CreatorApplicationStatus.PENDING.name().equalsIgnoreCase(profile.getVerificationStatus())
              ? "Bạn đã có hồ sơ Creator đang chờ duyệt."
              : "Tài khoản này đã có hồ sơ Creator.";
      throw new CreatorApplicationConflictException(message);
    }

    String channelName = request.channelName().trim();
    boolean channelNameTaken =
        profile == null
            ? producerProfileRepository.existsByChannelNameIgnoreCase(channelName)
            : producerProfileRepository.existsByChannelNameIgnoreCaseAndProducerProfileIdNot(
                channelName, profile.getProducerProfileId());
    if (channelNameTaken) {
      throw new CreatorApplicationConflictException("Tên kênh này đã được sử dụng.");
    }

    if (profile == null) {
      profile = new ProducerProfile();
      profile.setUser(applicant);
    }
    profile.setChannelName(channelName);
    profile.setDescription(request.introduction().trim());
    profile.setWebsiteUrl(trimToNull(request.portfolioUrl()));
    profile.setVerificationStatus(CreatorApplicationStatus.PENDING.name());
    profile.setReviewNote(null);

    return toResponse(producerProfileRepository.save(profile));
  }

  @Transactional(readOnly = true)
  public CreatorApplicationResponse getMyLatestApplication(UUID applicantId) {
    return producerProfileRepository
        .findByUser_UserId(applicantId)
        .map(this::toResponse)
        .orElseThrow(CreatorApplicationNotFoundException::new);
  }

  @Transactional(readOnly = true)
  public List<CreatorApplicationResponse> getPendingApplications() {
    return producerProfileRepository
        .findAllByVerificationStatusIgnoreCaseOrderByChannelNameAsc(
            CreatorApplicationStatus.PENDING.name())
        .stream()
        .map(this::toResponse)
        .toList();
  }

  @Transactional
  public CreatorApplicationResponse approve(UUID reviewerId, UUID profileId, String note) {
    requireRole(reviewerId, UserRole.ADMIN, "Chỉ Admin mới được duyệt hồ sơ Creator.");
    ProducerProfile profile = requirePendingProfile(profileId);
    AppUser applicant = profile.getUser();
    requireActive(applicant);
    if (!hasRole(applicant, UserRole.LISTENER)) {
      throw new CreatorApplicationConflictException(
          "Tài khoản không còn ở vai trò Listener để được duyệt Creator.");
    }

    Role creatorRole =
        roleRepository
            .findByRoleCode(UserRole.CREATOR.name())
            .orElseThrow(
                () -> new IllegalStateException("Role CREATOR chưa được seed trong database."));
    applicant.setRole(creatorRole);
    appUserRepository.save(applicant);

    profile.setVerificationStatus(CreatorApplicationStatus.APPROVED.name());
    profile.setReviewNote(trimToNull(note));
    support.audit(requireUser(reviewerId), "APPROVE_CREATOR", "CREATOR_PROFILE", profileId, note);
    support.notify(
        applicant,
        "CREATOR_APPLICATION",
        "Hồ sơ Creator được duyệt",
        note == null ? "Đăng nhập lại để sử dụng quyền Creator." : note);
    ProducerProfile approved = producerProfileRepository.save(profile);
    membershipPlanDefaults.provisionFor(approved);
    return toResponse(approved);
  }

  @Transactional
  public CreatorApplicationResponse reject(UUID reviewerId, UUID profileId, String note) {
    requireRole(reviewerId, UserRole.ADMIN, "Chỉ Admin mới được từ chối hồ sơ Creator.");
    if (note == null || note.isBlank()) {
      throw new CreatorApplicationConflictException("Admin cần ghi lý do khi từ chối hồ sơ.");
    }

    ProducerProfile profile = requirePendingProfile(profileId);
    profile.setVerificationStatus(CreatorApplicationStatus.REJECTED.name());
    profile.setReviewNote(note.trim());
    support.audit(requireUser(reviewerId), "REJECT_CREATOR", "CREATOR_PROFILE", profileId, note);
    support.notify(profile.getUser(), "CREATOR_APPLICATION", "Hồ sơ Creator bị từ chối", note);
    return toResponse(producerProfileRepository.save(profile));
  }

  private ProducerProfile requirePendingProfile(UUID profileId) {
    ProducerProfile profile =
        producerProfileRepository
            .findByIdForUpdate(profileId)
            .orElseThrow(CreatorApplicationNotFoundException::new);
    if (!CreatorApplicationStatus.PENDING
        .name()
        .equalsIgnoreCase(profile.getVerificationStatus())) {
      throw new CreatorApplicationConflictException("Hồ sơ này đã được xử lý trước đó.");
    }
    return profile;
  }

  private AppUser requireUser(UUID userId) {
    return appUserRepository
        .findById(userId)
        .orElseThrow(
            () -> new CreatorApplicationConflictException("Không tìm thấy tài khoản hiện tại."));
  }

  private void requireRole(UUID userId, UserRole expectedRole, String errorMessage) {
    AppUser user = requireUser(userId);
    requireActive(user);
    if (!hasRole(user, expectedRole)) {
      throw new CreatorApplicationConflictException(errorMessage);
    }
  }

  private void requireActive(AppUser user) {
    if (!Boolean.TRUE.equals(user.getIsActive())) {
      throw new CreatorApplicationConflictException("Tài khoản hiện không hoạt động.");
    }
  }

  private boolean hasRole(AppUser user, UserRole role) {
    return user.getRole() != null && role.name().equalsIgnoreCase(user.getRole().getRoleCode());
  }

  private CreatorApplicationResponse toResponse(ProducerProfile profile) {
    AppUser applicant = profile.getUser();
    String status = profile.getVerificationStatus();
    Instant reviewedAt =
        CreatorApplicationStatus.PENDING.name().equalsIgnoreCase(status)
            ? null
            : profile.getUpdatedAt();
    return new CreatorApplicationResponse(
        profile.getProducerProfileId(),
        applicant.getUserId(),
        applicant.getUsername(),
        applicant.getEmail(),
        profile.getChannelName(),
        profile.getDescription(),
        profile.getWebsiteUrl(),
        status,
        profile.getReviewNote(),
        profile.getCreatedAt(),
        reviewedAt);
  }

  private String trimToNull(String value) {
    if (value == null || value.isBlank()) {
      return null;
    }
    return value.trim();
  }
}
