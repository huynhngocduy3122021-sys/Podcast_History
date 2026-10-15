package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.UserWallet;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.*;

public interface UserWalletRepository
    extends JpaRepository<UserWallet, UUID>, JpaSpecificationExecutor<UserWallet> {
  @Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
  @Query("select w from UserWallet w where w.userWalletId=:id")
  Optional<UserWallet> lockById(@org.springframework.data.repository.query.Param("id") UUID id);
}
