package com.prmteam7.podcasthistory.config;

import com.prmteam7.podcasthistory.repository.AppUserRepository;
import java.util.UUID;
import org.springframework.security.oauth2.core.*;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

@Component
public class AccountJwtValidator implements OAuth2TokenValidator<Jwt> {
  private final AppUserRepository users;

  public AccountJwtValidator(AppUserRepository users) {
    this.users = users;
  }

  public OAuth2TokenValidatorResult validate(Jwt jwt) {
    try {
      var u = users.findByUserId(UUID.fromString(jwt.getClaimAsString("user_id"))).orElse(null);
      Number version = jwt.getClaim("token_version");
      long tokenVersion = version == null ? 0L : version.longValue();
      if (u != null
          && Boolean.TRUE.equals(u.getIsActive())
          && u.getRole().getRoleCode().equals(jwt.getClaimAsString("role"))
          && u.getTokenVersion() == tokenVersion
          && "access".equals(jwt.getClaimAsString("token_type")))
        return OAuth2TokenValidatorResult.success();
    } catch (IllegalArgumentException | ClassCastException ignored) {
    }
    return OAuth2TokenValidatorResult.failure(
        new OAuth2Error(
            "invalid_token", "Phiên đã bị thu hồi hoặc tài khoản không hoạt động.", null));
  }
}
