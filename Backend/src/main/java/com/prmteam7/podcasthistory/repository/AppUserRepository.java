package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.AppUser;
import java.util.Optional;
import java.util.UUID;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AppUserRepository
    extends JpaRepository<AppUser, UUID>,
        org.springframework.data.jpa.repository.JpaSpecificationExecutor<AppUser> {
  @org.springframework.data.jpa.repository.EntityGraph(attributePaths = "role")
  Optional<AppUser> findByUserId(UUID userId);

  @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
  @Query("select u from AppUser u where u.userId=:id")
  Optional<AppUser> lockById(@Param("id") UUID id);

  long countByIsActiveTrue();

  @Override
  @org.springframework.data.jpa.repository.EntityGraph(attributePaths = "role")
  org.springframework.data.domain.Page<AppUser> findAll(
      org.springframework.data.jpa.domain.Specification<AppUser> spec,
      org.springframework.data.domain.Pageable page);

  boolean existsByUsernameIgnoreCase(String username);

  boolean existsByEmailIgnoreCase(String email);

  @Query(value = "select cast(pg_advisory_xact_lock(hashtextextended(lower(:identifier), 0)) as text)", nativeQuery = true)
  String lockIdentifier(@Param("identifier") String identifier);

  default void lockRegistrationIdentifiers(String username, String email) {
    java.util.stream.Stream.of(username, email).map(value -> value.trim().toLowerCase(java.util.Locale.ROOT))
        .distinct().sorted().forEach(this::lockIdentifier);
  }

    @Query("""
            select user
            from AppUser user
            join fetch user.role
            where lower(user.username) = lower(:identifier)
               or lower(user.email) = lower(:identifier)
            """)
    Optional<AppUser> findByIdentifier(@Param("identifier") String identifier);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select user from AppUser user join fetch user.role where user.userId = :userId")
    Optional<AppUser> findByIdForUpdate(@Param("userId") UUID userId);
}
