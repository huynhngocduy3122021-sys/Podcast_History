package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.MilestoneDraft;
import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.List;
import java.util.Collection;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

public interface MilestoneDraftRepository extends JpaRepository<MilestoneDraft, UUID> {
    long countByStage_ContractStageId(UUID stageId);
    List<MilestoneDraft> findAllByStage_ContractStageIdOrderByDraftNumberDesc(UUID stageId);
    Optional<MilestoneDraft> findFirstByStage_ContractStageIdAndStatusNotInOrderByDraftNumberDesc(
            UUID stageId, Collection<String> excludedStatuses);

    @Query("select d.id from MilestoneDraft d where d.status = 'PENDING' or "
            + "(d.status = 'PROCESSING' and d.processingStartedAt < :staleBefore) order by d.createdAt")
    List<UUID> findReviewCandidates(@Param("staleBefore") Instant staleBefore, Pageable page);

    @Modifying
    @Query("update MilestoneDraft d set d.status = 'PROCESSING', d.attemptToken = :token, "
            + "d.processingStartedAt = :now where d.id = :id and "
            + "(d.status = 'PENDING' or (d.status = 'PROCESSING' and d.processingStartedAt < :staleBefore))")
    int claim(@Param("id") UUID id, @Param("token") UUID token,
              @Param("now") Instant now, @Param("staleBefore") Instant staleBefore);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select d from MilestoneDraft d where d.id = :id")
    Optional<MilestoneDraft> lockById(@Param("id") UUID id);
}
