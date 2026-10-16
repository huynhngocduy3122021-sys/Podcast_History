package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.Poll;
import jakarta.persistence.LockModeType;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

public interface PollRepository extends JpaRepository<Poll, UUID>, JpaSpecificationExecutor<Poll> {
    @Override
    @EntityGraph(attributePaths = {"producerProfile", "series", "podcast"})
    Page<Poll> findAll(Specification<Poll> spec, Pageable pageable);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from Poll p where p.pollId = :id")
    Optional<Poll> lockById(@Param("id") UUID id);
}
