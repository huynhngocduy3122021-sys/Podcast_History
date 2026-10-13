package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.request.LoginRequest;
import com.prmteam7.podcasthistory.dto.request.RegisterRequest;
import com.prmteam7.podcasthistory.dto.response.LoginResponse;
import com.prmteam7.podcasthistory.dto.response.RegisterResponse;
import com.prmteam7.podcasthistory.enums.TokenType;
import com.prmteam7.podcasthistory.exception.AccountAlreadyExistsException;
import com.prmteam7.podcasthistory.exception.InvalidCredentialsException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.RefreshToken;
import com.prmteam7.podcasthistory.model.Role;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.RefreshTokenRepository;
import com.prmteam7.podcasthistory.repository.RoleRepository;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Optional;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

  private static final String ISSUER = "podcast-history-backend";
  private static final String DEFAULT_REGISTERED_ROLE = "LISTENER";

  private final AppUserRepository appUserRepository;
  private final RefreshTokenRepository refreshTokenRepository;
  private final RoleRepository roleRepository;
  private final PasswordEncoder passwordEncoder;
  private final JwtEncoder jwtEncoder;
  private final long accessTokenTtlSeconds;
  private final long refreshTokenTtlSeconds;
  private final SecureRandom secureRandom = new SecureRandom();

  public AuthService(
      AppUserRepository appUserRepository,
      RefreshTokenRepository refreshTokenRepository,
      RoleRepository roleRepository,
      PasswordEncoder passwordEncoder,
      JwtEncoder jwtEncoder,
      @Value("${security.jwt.access-token-ttl-seconds:600}") long accessTokenTtlSeconds,
      @Value("${security.jwt.refresh-token-ttl-seconds:604800}") long refreshTokenTtlSeconds) {
    this.appUserRepository = appUserRepository;
    this.refreshTokenRepository = refreshTokenRepository;
    this.roleRepository = roleRepository;
    this.passwordEncoder = passwordEncoder;
    this.jwtEncoder = jwtEncoder;
    if (accessTokenTtlSeconds <= 0 || refreshTokenTtlSeconds <= 0) {
      throw new IllegalArgumentException("JWT token lifetimes must be positive.");
    }
    this.accessTokenTtlSeconds = accessTokenTtlSeconds;
    this.refreshTokenTtlSeconds = refreshTokenTtlSeconds;
  }

  @Transactional
  public RegisterResponse register(RegisterRequest request) {
    String username = request.username().trim();
    String email = request.email().trim();
    appUserRepository.lockRegistrationIdentifiers(username, email);
    if (appUserRepository.existsByUsernameIgnoreCase(username)
        || appUserRepository.existsByEmailIgnoreCase(email)
        || appUserRepository.existsByEmailIgnoreCase(username)
        || appUserRepository.existsByUsernameIgnoreCase(email)) {
      throw new AccountAlreadyExistsException();
    }

    Role listenerRole =
        roleRepository
            .findByRoleCode(DEFAULT_REGISTERED_ROLE)
            .orElseThrow(() -> new IllegalStateException("The LISTENER role has not been seeded."));

    AppUser user = new AppUser();
    user.setRole(listenerRole);
    user.setUsername(username);
    user.setEmail(email);
    user.setPasswordHash(passwordEncoder.encode(request.password()));
    user.setDisplayName(request.displayName().trim());
    user.setIsActive(true);
    user.setIsVerified(false);
    AppUser savedUser = appUserRepository.save(user);

    return new RegisterResponse(
        savedUser.getUserId(),
        savedUser.getUsername(),
        savedUser.getEmail(),
        savedUser.getDisplayName(),
        listenerRole.getRoleCode());
  }

  @Transactional
  public LoginResponse login(LoginRequest request) {
    AppUser user =
        appUserRepository
            .findByIdentifier(request.identifier().trim())
            .filter(
                candidate ->
                    passwordEncoder.matches(request.password(), candidate.getPasswordHash()))
            .filter(candidate -> Boolean.TRUE.equals(candidate.getIsActive()))
            .orElseThrow(InvalidCredentialsException::new);

    Instant now = Instant.now();
    user.setLastLoginAt(now);
    appUserRepository.save(user);
    return issueTokenPair(user, UUID.randomUUID(), now);
  }

  @Transactional
  public Optional<LoginResponse> refresh(String presentedRefreshToken) {
    if (presentedRefreshToken == null || presentedRefreshToken.isBlank()) {
      return Optional.empty();
    }

    String tokenHash = hashRefreshToken(presentedRefreshToken);
    Optional<RefreshToken> storedToken = refreshTokenRepository.findByTokenHashForUpdate(tokenHash);
    if (storedToken.isEmpty()) {
      return Optional.empty();
    }

    RefreshToken current = storedToken.get();
    Instant now = Instant.now();
    if (current.getRevokedAt() != null) {
      // A previously rotated token was replayed; revoke any remaining token in this family.
      refreshTokenRepository.revokeActiveTokensByFamilyId(current.getTokenFamilyId(), now);
      return Optional.empty();
    }
    if (!current.getExpiresAt().isAfter(now)) {
      current.setRevokedAt(now);
      return Optional.empty();
    }

    current.setRevokedAt(now);
    if (!Boolean.TRUE.equals(current.getUser().getIsActive())) {
      refreshTokenRepository.revokeActiveTokensByFamilyId(current.getTokenFamilyId(), now);
      return Optional.empty();
    }
    return Optional.of(issueTokenPair(current.getUser(), current.getTokenFamilyId(), now));
  }

  @Transactional
  public void logout(String presentedRefreshToken) {
    if (presentedRefreshToken == null || presentedRefreshToken.isBlank()) {
      return;
    }

    refreshTokenRepository
        .findByTokenHashForUpdate(hashRefreshToken(presentedRefreshToken))
        .ifPresent(
            token ->
                refreshTokenRepository.revokeActiveTokensByFamilyId(
                    token.getTokenFamilyId(), Instant.now()));
  }

  private LoginResponse issueTokenPair(AppUser user, UUID tokenFamilyId, Instant issuedAt) {
    Instant accessExpiresAt = issuedAt.plusSeconds(accessTokenTtlSeconds);
    String accessToken =
        jwtEncoder
            .encode(
                JwtEncoderParameters.from(
                    org.springframework.security.oauth2.jwt.JwsHeader.with(MacAlgorithm.HS256)
                        .build(),
                    JwtClaimsSet.builder()
                        .issuer(ISSUER)
                        .issuedAt(issuedAt)
                        .expiresAt(accessExpiresAt)
                        .subject(user.getUsername())
                        .claim("token_type", TokenType.ACCESS.claimValue())
                        .claim("user_id", user.getUserId().toString())
                        .claim("token_version", user.getTokenVersion())
                        .claim("email", user.getEmail())
                        .claim("role", user.getRole().getRoleCode())
                        .build()))
            .getTokenValue();

    String refreshTokenValue = createRefreshTokenValue();
    RefreshToken refreshToken = new RefreshToken();
    refreshToken.setUser(user);
    refreshToken.setTokenHash(hashRefreshToken(refreshTokenValue));
    refreshToken.setTokenFamilyId(tokenFamilyId);
    refreshToken.setExpiresAt(issuedAt.plusSeconds(refreshTokenTtlSeconds));
    refreshTokenRepository.save(refreshToken);

    return new LoginResponse(
        accessToken,
        refreshTokenValue,
        "Bearer",
        accessTokenTtlSeconds,
        refreshTokenTtlSeconds,
        new LoginResponse.UserSummary(
            user.getUserId(),
            user.getUsername(),
            user.getEmail(),
            user.getDisplayName(),
            user.getRole().getRoleCode()));
  }

  private String createRefreshTokenValue() {
    byte[] randomBytes = new byte[32];
    secureRandom.nextBytes(randomBytes);
    return Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);
  }

  private String hashRefreshToken(String refreshToken) {
    try {
      byte[] digest =
          MessageDigest.getInstance("SHA-256")
              .digest(refreshToken.getBytes(java.nio.charset.StandardCharsets.UTF_8));
      return HexFormat.of().formatHex(digest);
    } catch (NoSuchAlgorithmException exception) {
      throw new IllegalStateException("SHA-256 is unavailable.", exception);
    }
  }
}
