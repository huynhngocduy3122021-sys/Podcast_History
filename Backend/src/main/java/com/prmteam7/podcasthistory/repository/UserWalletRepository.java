package com.prmteam7.podcasthistory.repository;

import java.util.Optional;
import java.util.UUID;

import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.prmteam7.podcasthistory.model.UserWallet;

public interface UserWalletRepository extends JpaRepository<UserWallet, UUID> {

    @EntityGraph(attributePaths = {"user", "user.role"})
    @Query("select wallet from UserWallet wallet")
    Page<UserWallet> findAllForAdmin(Pageable pageable);

    @EntityGraph(attributePaths = {"user", "user.role"})
    @Query("select wallet from UserWallet wallet where wallet.userWalletId = :id")
    Optional<UserWallet> findAdminById(@Param("id") UUID id);

    Optional<UserWallet> findByUser_UserId(UUID userId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select wallet from UserWallet wallet where wallet.user.userId = :userId")
    Optional<UserWallet> findByUserIdForUpdate(@Param("userId") UUID userId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select wallet from UserWallet wallet where wallet.userWalletId = :id")
    Optional<UserWallet> lockById(@Param("id") UUID id);
}
