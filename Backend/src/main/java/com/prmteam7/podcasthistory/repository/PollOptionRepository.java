package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.PollOption;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

public interface PollOptionRepository extends JpaRepository<PollOption, UUID> {
    List<PollOption> findAllByPoll_PollIdOrderBySortOrderAsc(UUID pollId);
    Optional<PollOption> findByPollOptionIdAndPoll_PollId(UUID optionId, UUID pollId);

    @Modifying
    @Query("delete from PollOption o where o.poll.pollId = :id")
    void deleteOptions(@Param("id") UUID pollId);
}
