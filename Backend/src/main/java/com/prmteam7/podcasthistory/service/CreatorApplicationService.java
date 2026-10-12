package com.prmteam7.podcasthistory.service;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.prmteam7.podcasthistory.dto.request.CreatorApplicationRequest;
import com.prmteam7.podcasthistory.dto.response.CreatorApplicationResponse;
import com.prmteam7.podcasthistory.enums.CreatorApplicationStatus;
import com.prmteam7.podcasthistory.enums.UserRole;
import com.prmteam7.podcasthistory.exception.CreatorApplicationConflictException;
import com.prmteam7.podcasthistory.exception.CreatorApplicationNotFoundException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.ProducerApplication;
import com.prmteam7.podcasthistory.model.ProducerProfile;
import com.prmteam7.podcasthistory.model.Role;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.ProducerApplicationRepository;
import com.prmteam7.podcasthistory.repository.ProducerProfileRepository;
import com.prmteam7.podcasthistory.repository.RoleRepository;

@Service
public class CreatorApplicationService {

    private final ProducerApplicationRepository applicationRepository;
    private final ProducerProfileRepository producerProfileRepository;
    private final AppUserRepository appUserRepository;
    private final RoleRepository roleRepository;

    public CreatorApplicationService(
            ProducerApplicationRepository applicationRepository,
            ProducerProfileRepository producerProfileRepository,
            AppUserRepository appUserRepository,
            RoleRepository roleRepository) {
        this.applicationRepository = applicationRepository;
        this.producerProfileRepository = producerProfileRepository;
        this.appUserRepository = appUserRepository;
        this.roleRepository = roleRepository;
    }

    @Transactional
    public CreatorApplicationResponse submit(UUID applicantId, CreatorApplicationRequest request) {
        AppUser applicant = requireUser(applicantId);
        requireActive(applicant);
        if (!hasRole(applicant, UserRole.LISTENER)) {
            throw new CreatorApplicationConflictException("Chỉ tài khoản Listener mới có thể đăng ký làm Creator.");
        }
        if (applicationRepository.existsByUser_UserIdAndApplicationStatus(
                applicantId, CreatorApplicationStatus.PENDING.name())) {
            throw new CreatorApplicationConflictException("Bạn đã có một hồ sơ Creator đang chờ duyệt.");
        }

        String channelName = request.channelName().trim();
        if (producerProfileRepository.existsByChannelNameIgnoreCase(channelName)) {
            throw new CreatorApplicationConflictException("Tên kênh này đã được sử dụng.");
        }

        ProducerApplication application = new ProducerApplication();
        application.setUser(applicant);
        application.setChannelName(channelName);
        application.setIntroduction(request.introduction().trim());
        application.setPortfolioUrl(trimToNull(request.portfolioUrl()));
        application.setApplicationStatus(CreatorApplicationStatus.PENDING.name());
        application.setSubmittedAt(Instant.now());
        return toResponse(applicationRepository.save(application));
    }

    @Transactional(readOnly = true)
    public CreatorApplicationResponse getMyLatestApplication(UUID applicantId) {
        return applicationRepository.findFirstByUser_UserIdOrderBySubmittedAtDesc(applicantId)
                .map(this::toResponse)
                .orElseThrow(CreatorApplicationNotFoundException::new);
    }

    @Transactional(readOnly = true)
    public List<CreatorApplicationResponse> getPendingApplications() {
        return applicationRepository
                .findAllByApplicationStatusOrderBySubmittedAtAsc(CreatorApplicationStatus.PENDING.name())
                .stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public CreatorApplicationResponse approve(UUID reviewerId, UUID applicationId, String note) {
        requireRole(reviewerId, UserRole.ADMIN, "Chỉ Admin mới được duyệt hồ sơ Creator.");
        ProducerApplication application = requirePendingApplication(applicationId);
        AppUser applicant = application.getUser();
        requireActive(applicant);
        if (!hasRole(applicant, UserRole.LISTENER)) {
            throw new CreatorApplicationConflictException("Tài khoản không còn ở vai trò Listener để được duyệt Creator.");
        }

        if (producerProfileRepository.existsByUser_UserId(applicant.getUserId())) {
            throw new CreatorApplicationConflictException("Tài khoản này đã có kênh Creator.");
        }
        if (producerProfileRepository.existsByChannelNameIgnoreCase(application.getChannelName())) {
            throw new CreatorApplicationConflictException("Tên kênh đã được một Creator khác sử dụng.");
        }

        Role creatorRole = roleRepository.findByRoleCode(UserRole.CREATOR.name())
                .orElseThrow(() -> new IllegalStateException("Role CREATOR chưa được seed trong database."));
        applicant.setRole(creatorRole);
        appUserRepository.save(applicant);

        ProducerProfile profile = new ProducerProfile();
        profile.setUser(applicant);
        profile.setChannelName(application.getChannelName());
        profile.setDescription(application.getIntroduction());
        profile.setVerificationStatus(CreatorApplicationStatus.APPROVED.name());
        producerProfileRepository.save(profile);

        application.setApplicationStatus(CreatorApplicationStatus.APPROVED.name());
        application.setReviewNote(trimToNull(note));
        application.setReviewedAt(Instant.now());
        return toResponse(applicationRepository.save(application));
    }

    @Transactional
    public CreatorApplicationResponse reject(UUID reviewerId, UUID applicationId, String note) {
        requireRole(reviewerId, UserRole.ADMIN, "Chỉ Admin mới được từ chối hồ sơ Creator.");
        if (note == null || note.isBlank()) {
            throw new CreatorApplicationConflictException("Admin cần ghi lý do khi từ chối hồ sơ.");
        }

        ProducerApplication application = requirePendingApplication(applicationId);
        application.setApplicationStatus(CreatorApplicationStatus.REJECTED.name());
        application.setReviewNote(note.trim());
        application.setReviewedAt(Instant.now());
        return toResponse(applicationRepository.save(application));
    }

    private ProducerApplication requirePendingApplication(UUID applicationId) {
        ProducerApplication application = applicationRepository.findByIdForUpdate(applicationId)
                .orElseThrow(CreatorApplicationNotFoundException::new);
        if (!CreatorApplicationStatus.PENDING.name().equals(application.getApplicationStatus())) {
            throw new CreatorApplicationConflictException("Hồ sơ này đã được xử lý trước đó.");
        }
        return application;
    }

    private AppUser requireUser(UUID userId) {
        return appUserRepository.findById(userId)
                .orElseThrow(() -> new CreatorApplicationConflictException("Không tìm thấy tài khoản hiện tại."));
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

    private CreatorApplicationResponse toResponse(ProducerApplication application) {
        AppUser applicant = application.getUser();
        return new CreatorApplicationResponse(
                application.getProducerApplicationId(),
                applicant.getUserId(),
                applicant.getUsername(),
                applicant.getEmail(),
                application.getChannelName(),
                application.getIntroduction(),
                application.getPortfolioUrl(),
                application.getApplicationStatus(),
                application.getReviewNote(),
                application.getSubmittedAt(),
                application.getReviewedAt());
    }

    private String trimToNull(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return value.trim();
    }
}
