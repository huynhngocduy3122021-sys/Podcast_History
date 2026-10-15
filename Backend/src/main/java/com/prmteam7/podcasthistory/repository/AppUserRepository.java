package com.prmteam7.podcasthistory.repository;

import java.util.Optional;
import java.util.UUID;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.prmteam7.podcasthistory.model.AppUser;

public interface AppUserRepository extends JpaRepository<AppUser, UUID> {

    boolean existsByUsernameIgnoreCase(String username);

    boolean existsByEmailIgnoreCase(String email);

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
