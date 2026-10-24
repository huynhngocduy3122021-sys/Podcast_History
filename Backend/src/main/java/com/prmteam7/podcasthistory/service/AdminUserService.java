package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.request.AdminRequests.*;
import com.prmteam7.podcasthistory.dto.response.AdminResponses.*;
import com.prmteam7.podcasthistory.enums.UserRole;
import com.prmteam7.podcasthistory.exception.*;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.time.Instant;
import java.util.*;
import org.springframework.data.domain.Page;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class AdminUserService {
  private final AppUserRepository users;
  private final RoleRepository roles;
  private final ProducerProfileRepository profiles;
  private final RefreshTokenRepository tokens;
  private final PasswordEncoder passwords;
  private final AdminSupportService support;
  private final AdminAuditRepository audits;

  public AdminUserService(
      AppUserRepository users,
      RoleRepository roles,
      ProducerProfileRepository profiles,
      RefreshTokenRepository tokens,
      PasswordEncoder passwords,
      AdminSupportService support,
      AdminAuditRepository audits) {
    this.users = users;
    this.roles = roles;
    this.profiles = profiles;
    this.tokens = tokens;
    this.passwords = passwords;
    this.support = support;
    this.audits = audits;
  }

  public Page<UserItem> list(
      UUID actor, String search, UserRole role, Boolean active, int page, int size) {
    support.actor(actor, true);
    Specification<AppUser> spec =
        (r, q, c) -> {
          var clauses = new ArrayList<jakarta.persistence.criteria.Predicate>();
          if (search != null && !search.isBlank()) {
            String pattern = "%" + search.trim().toLowerCase(Locale.ROOT) + "%";
            clauses.add(
                c.or(
                    c.like(c.lower(r.get("username")), pattern),
                    c.like(c.lower(r.get("email")), pattern),
                    c.like(c.lower(r.get("displayName")), pattern)));
          }
          if (role != null) clauses.add(c.equal(r.get("role").get("roleCode"), role.name()));
          if (active != null) clauses.add(c.equal(r.get("isActive"), active));
          return c.and(clauses.toArray(jakarta.persistence.criteria.Predicate[]::new));
        };
    return users.findAll(spec, AdminSupportService.page(page, size)).map(this::item);
  }

  public UserItem detail(UUID actor, UUID id) {
    support.actor(actor, true);
    return item(require(id));
  }

  @Transactional
  public UserItem update(UUID actor, UUID id, UserProfile request) {
    AppUser admin = support.actor(actor, true);
    AppUser u = lock(id);
    u.setDisplayName(request.displayName().trim());
    u.setAvatarUrl(request.avatarUrl());
    u.setBio(request.bio());
    support.audit(admin, "UPDATE_PROFILE", "USER", id, "Cập nhật hồ sơ người dùng.");
    return item(users.save(u));
  }

  @Transactional
  public UserItem access(UUID actor, UUID id, UserAccess request) {
    AppUser admin = support.actor(actor, true);
    AppUser u = lock(id);
    protectAdmin(u);
    u.setIsActive(request.active());
    revoke(u);
    support.audit(
        admin, request.active() ? "UNLOCK_USER" : "LOCK_USER", "USER", id, request.note());
    support.notify(u, "ACCOUNT_ACCESS",
        request.active() ? "Tài khoản của bạn đã được mở khóa" : "Tài khoản của bạn đã bị khóa",
        request.note());
    return item(users.save(u));
  }

  @Transactional
  public UserItem verify(UUID actor, UUID id, UserVerification request) {
    AppUser admin = support.actor(actor, true);
    AppUser u = lock(id);
    u.setIsVerified(request.verified());
    support.audit(admin, "VERIFY_USER", "USER", id, request.note());
    return item(users.save(u));
  }

  @Transactional
  public UserItem role(UUID actor, UUID id, UserRoleChange request) {
    AppUser admin = support.actor(actor, true);
    AppUser u = lock(id);
    protectAdmin(u);
    if (request.role() == UserRole.ADMIN)
      throw new ResourceForbiddenException("Không tạo thêm Admin qua API phân quyền.");
    if (request.role() == UserRole.CREATOR
        && profiles
            .findByUser_UserId(id)
            .filter(p -> "APPROVED".equalsIgnoreCase(p.getVerificationStatus()))
            .isEmpty())
      throw new ResourceConflictException("Cần duyệt hồ sơ Creator trước khi cấp role CREATOR.");
    u.setRole(
        roles
            .findByRoleCode(request.role().name())
            .orElseThrow(() -> new ResourceNotFoundException("Role không tồn tại.")));
    revoke(u);
    support.audit(admin, "CHANGE_ROLE", "USER", id, request.note());
    String roleTitle = switch (request.role()) {
      case LISTENER -> "Bạn đã được cấp vai trò Listener";
      case CREATOR -> "Bạn đã được cấp vai trò Content Creator";
      case STAFF -> "Bạn đã được cấp vai trò Staff";
      case ADMIN -> "Bạn đã được cấp vai trò Admin";
    };
    support.notify(u, "ACCOUNT_ROLE", roleTitle, request.note());
    return item(users.save(u));
  }

  @Transactional
  public UserItem revokeSessions(UUID actor, UUID id, String note) {
    AppUser admin = support.actor(actor, true);
    AppUser u = lock(id);
    revoke(u);
    support.audit(admin, "REVOKE_SESSIONS", "USER", id, note);
    return item(users.save(u));
  }

  @Transactional
  public UserItem createStaff(UUID actor, StaffCreate request) {
    AppUser admin = support.actor(actor, true);
    users.lockRegistrationIdentifiers(request.username(), request.email());
    if (users.existsByUsernameIgnoreCase(request.username().trim())
        || users.existsByEmailIgnoreCase(request.email().trim())
        || users.findByIdentifier(request.username().trim()).isPresent()
        || users.findByIdentifier(request.email().trim()).isPresent())
      throw new ResourceConflictException("Username/email đã được dùng.");
    AppUser u = new AppUser();
    u.setUsername(request.username().trim());
    u.setEmail(request.email().trim());
    u.setDisplayName(request.displayName().trim());
    u.setPasswordHash(passwords.encode(request.password()));
    u.setRole(
        roles
            .findByRoleCode("STAFF")
            .orElseThrow(() -> new ResourceNotFoundException("Role STAFF chưa được seed.")));
    u.setIsActive(true);
    u.setIsVerified(true);
    u = users.save(u);
    support.audit(admin, "CREATE_STAFF", "USER", u.getUserId(), "Tạo tài khoản Staff.");
    return item(u);
  }

  public Page<AuditItem> auditLog(UUID actor, String type, UUID resourceId, int page, int size) {
    support.actor(actor, true);
    return audits
        .findAll(
            (r, q, c) ->
                c.and(
                    type == null
                        ? c.conjunction()
                        : c.equal(r.get("resourceType"), type.toUpperCase(Locale.ROOT)),
                    resourceId == null
                        ? c.conjunction()
                        : c.equal(r.get("resourceId"), resourceId)),
            AdminSupportService.page(page, size))
        .map(
            a ->
                new AuditItem(
                    a.getAuditId(),
                    a.getActor().getUserId(),
                    a.getAction(),
                    a.getResourceType(),
                    a.getResourceId(),
                    a.getNote(),
                    a.getCreatedAt()));
  }

  private void revoke(AppUser u) {
    u.setTokenVersion(u.getTokenVersion() + 1);
    tokens.revokeByUserId(u.getUserId(), Instant.now());
  }

  private void protectAdmin(AppUser u) {
    if ("ADMIN".equals(u.getRole().getRoleCode()))
      throw new ResourceForbiddenException(
          "Không khóa hoặc đổi vai trò tài khoản Admin qua API này.");
  }

  private AppUser require(UUID id) {
    return users
        .findByUserId(id)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy user."));
  }

  private AppUser lock(UUID id) {
    return users
        .lockById(id)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy user."));
  }

  private UserItem item(AppUser u) {
    return new UserItem(
        u.getUserId(),
        u.getUsername(),
        u.getEmail(),
        u.getDisplayName(),
        u.getAvatarUrl(),
        u.getBio(),
        u.getRole().getRoleCode(),
        Boolean.TRUE.equals(u.getIsActive()),
        Boolean.TRUE.equals(u.getIsVerified()),
        u.getCreatedAt(),
        u.getLastLoginAt());
  }
}
