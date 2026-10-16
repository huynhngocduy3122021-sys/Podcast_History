package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.PollVote;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

public interface PollVoteRepository extends JpaRepository<PollVote, UUID> {
    @EntityGraph(attributePaths = {"pollOption", "user"})
    Optional<PollVote> findByPoll_PollIdAndUser_UserId(UUID pollId, UUID userId);

    @EntityGraph(attributePaths = {"pollOption", "user"})
    Page<PollVote> findAllByPoll_PollIdOrderByCreatedAtDescPollVoteIdDesc(UUID pollId, Pageable pageable);

    boolean existsByPoll_PollId(UUID pollId);

    interface CountByOption {
        UUID getOptionId();
        long getTotal();
    }

    @Query("select v.pollOption.pollOptionId as optionId, count(v) as total from PollVote v "
            + "where v.poll.pollId = :id group by v.pollOption.pollOptionId")
    List<CountByOption> countOptions(@Param("id") UUID pollId);
}
