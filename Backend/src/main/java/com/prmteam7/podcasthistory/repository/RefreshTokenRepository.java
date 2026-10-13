package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.RefreshToken;
import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, UUID> {
  @Modifying
  @Query(
      "update RefreshToken t set t.revokedAt=:at where t.user.userId=:userId and t.revokedAt is"
          + " null")
  int revokeByUserId(@Param("userId") UUID userId, @Param("at") Instant at);

  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query(
      "select token from RefreshToken token join fetch token.user user join fetch user.role where"
          + " token.tokenHash = :tokenHash")
  Optional<RefreshToken> findByTokenHashForUpdate(@Param("tokenHash") String tokenHash);

  @Modifying
  @Query(
      "update RefreshToken token set token.revokedAt = :revokedAt where token.tokenFamilyId ="
          + " :familyId and token.revokedAt is null")
  int revokeActiveTokensByFamilyId(
      @Param("familyId") UUID familyId, @Param("revokedAt") Instant revokedAt);
}
