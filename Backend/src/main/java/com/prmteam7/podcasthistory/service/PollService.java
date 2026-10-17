package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.request.PollRequests;
import com.prmteam7.podcasthistory.dto.response.PollResponses.*;
import com.prmteam7.podcasthistory.enums.PollStatus;
import com.prmteam7.podcasthistory.exception.*;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import jakarta.persistence.criteria.Predicate;
import java.time.Instant;
import java.util.*;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class PollService {
    private final PollRepository polls;
    private final PollOptionRepository options;
    private final PollVoteRepository votes;
    private final AppUserRepository users;
    private final ProducerProfileRepository creators;
    private final SeriesRepository series;
    private final PodcastRepository podcasts;

    public PollService(PollRepository polls, PollOptionRepository options, PollVoteRepository votes,
            AppUserRepository users, ProducerProfileRepository creators, SeriesRepository series,
            PodcastRepository podcasts) {
        this.polls = polls;
        this.options = options;
        this.votes = votes;
        this.users = users;
        this.creators = creators;
        this.series = series;
        this.podcasts = podcasts;
    }

    public Page<Summary> myPolls(UUID userId, PollStatus status, UUID seriesId, UUID podcastId, int page, int size) {
        ProducerProfile creator = creator(userId);
        return polls.findAll(filter(creator.getProducerProfileId(), false, status, seriesId, podcastId), page(page, size))
                .map(this::summary);
    }

    public Detail myPoll(UUID userId, UUID pollId) {
        return detail(owned(userId, pollId, false));
    }

    @Transactional
    public Detail create(UUID userId, PollRequests.Write request) {
        Poll poll = new Poll();
        poll.setProducerProfile(creator(userId));
        poll.setStatus(PollStatus.DRAFT.name());
        apply(poll, request);
        // save may merge a versioned entity; options must reference the managed result.
        poll = polls.save(poll);
        saveOptions(poll, request.options());
        return detail(poll);
    }

    @Transactional
    public Detail update(UUID userId, UUID pollId, PollRequests.Write request) {
        Poll poll = owned(userId, pollId, true);
        requireStatus(poll, PollStatus.DRAFT);
        if (votes.existsByPoll_PollId(pollId)) {
            throw new ResourceConflictException("Poll đã có câu trả lời, không thể thay đổi câu hỏi/option.");
        }
        apply(poll, request);
        options.deleteOptions(pollId);
        saveOptions(poll, request.options());
        return detail(polls.save(poll));
    }

    @Transactional
    public Detail publish(UUID userId, UUID pollId) {
        Poll poll = owned(userId, pollId, true);
        requireStatus(poll, PollStatus.DRAFT);
        if (options.findAllByPoll_PollIdOrderBySortOrderAsc(pollId).size() < 2) {
            throw new ResourceConflictException("Poll cần ít nhất hai option trước khi công bố.");
        }
        if (poll.getEndsAt() != null && !poll.getEndsAt().isAfter(Instant.now())) {
            throw new ResourceConflictException("Poll đã hết thời hạn nhận câu trả lời.");
        }
        poll.setStatus(PollStatus.OPEN.name());
        return detail(polls.save(poll));
    }

    @Transactional
    public Detail close(UUID userId, UUID pollId) {
        Poll poll = owned(userId, pollId, true);
        requireStatus(poll, PollStatus.OPEN);
        poll.setStatus(PollStatus.CLOSED.name());
        return detail(polls.save(poll));
    }

    @Transactional
    public void delete(UUID userId, UUID pollId) {
        Poll poll = owned(userId, pollId, true);
        poll.setStatus(PollStatus.DELETED.name());
        polls.save(poll);
    }

    public Page<Summary> available(UUID viewerId, UUID creatorId, UUID seriesId, UUID podcastId, int page, int size) {
        activeUser(viewerId);
        ProducerProfile profile = creators.findById(creatorId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy kênh."));
        visibleCreator(profile);
        return polls.findAll(filter(creatorId, true, null, seriesId, podcastId), page(page, size)).map(this::summary);
    }

    public Detail view(UUID viewerId, UUID pollId) {
        activeUser(viewerId);
        return detail(visible(pollId, false));
    }

    public Results myResults(UUID userId, UUID pollId) {
        return results(owned(userId, pollId, false));
    }

    public Results publicResults(UUID viewerId, UUID pollId) {
        activeUser(viewerId);
        return results(visible(pollId, false));
    }

    public Page<Response> responses(UUID userId, UUID pollId, int page, int size) {
        owned(userId, pollId, false);
        Pageable pagination = PageRequest.of(Math.max(0, page), Math.min(100, Math.max(1, size)));
        return votes.findAllByPoll_PollIdOrderByCreatedAtDescPollVoteIdDesc(pollId, pagination)
                .map(this::response);
    }

    public Response myResponse(UUID userId, UUID pollId) {
        listener(userId);
        visible(pollId, false);
        return response(vote(pollId, userId));
    }

    @Transactional
    public Response answer(UUID userId, UUID pollId, PollRequests.Answer body, boolean update) {
        AppUser user = listener(userId);
        // Lock the poll before checking deadlines, existing responses and option ownership.
        // Publish/close/delete and every answer mutation use this same lock order.
        Poll poll = visible(pollId, true);
        accepting(poll);
        PollOption option = options.findByPollOptionIdAndPoll_PollId(body.optionId(), pollId)
                .orElseThrow(() -> new InvalidFlowRequestException("Option không thuộc poll này."));
        Optional<PollVote> existing = votes.findByPoll_PollIdAndUser_UserId(pollId, userId);
        if (update && existing.isEmpty()) {
            throw new ResourceNotFoundException("Bạn chưa gửi câu trả lời cho poll này.");
        }
        if (!update && existing.isPresent()) {
            throw new ResourceConflictException("Bạn đã trả lời. Dùng PUT responses/me để đổi lựa chọn.");
        }
        PollVote vote = existing.orElseGet(PollVote::new);
        vote.setPoll(poll);
        vote.setUser(user);
        vote.setPollOption(option);
        return response(votes.save(vote));
    }

    @Transactional
    public void withdraw(UUID userId, UUID pollId) {
        listener(userId);
        Poll poll = visible(pollId, true);
        accepting(poll);
        votes.delete(vote(pollId, userId));
    }

    private PollVote vote(UUID pollId, UUID userId) {
        return votes.findByPoll_PollIdAndUser_UserId(pollId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Chưa có câu trả lời cho poll này."));
    }

    private Poll owned(UUID userId, UUID pollId, boolean lock) {
        ProducerProfile creator = creator(userId);
        Poll poll = load(pollId, lock);
        if (!poll.getProducerProfile().getProducerProfileId().equals(creator.getProducerProfileId())) {
            throw new ResourceNotFoundException("Không tìm thấy poll thuộc kênh của bạn.");
        }
        return poll;
    }

    private Poll load(UUID pollId, boolean lock) {
        Poll poll = (lock ? polls.lockById(pollId) : polls.findById(pollId))
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy poll."));
        if (PollStatus.DELETED.name().equals(poll.getStatus())) {
            throw new ResourceNotFoundException("Không tìm thấy poll.");
        }
        return poll;
    }

    private Poll visible(UUID pollId, boolean lock) {
        Poll poll = load(pollId, lock);
        if (!Set.of(PollStatus.OPEN.name(), PollStatus.CLOSED.name()).contains(poll.getStatus())) {
            throw new ResourceNotFoundException("Không tìm thấy poll đã công bố.");
        }
        visibleCreator(poll.getProducerProfile());
        return poll;
    }

    private void visibleCreator(ProducerProfile profile) {
        AppUser user = profile.getUser();
        if (!"APPROVED".equalsIgnoreCase(profile.getVerificationStatus())
                || !Boolean.TRUE.equals(user.getIsActive())
                || !"CREATOR".equals(user.getRole().getRoleCode())) {
            throw new ResourceNotFoundException("Kênh không còn hoạt động hoặc chưa được duyệt.");
        }
    }

    private AppUser activeUser(UUID userId) {
        return users.findByUserId(userId).filter(user -> Boolean.TRUE.equals(user.getIsActive()))
                .orElseThrow(() -> new ResourceForbiddenException("Tài khoản không hoạt động."));
    }

    private AppUser listener(UUID userId) {
        AppUser user = activeUser(userId);
        if (!"LISTENER".equals(user.getRole().getRoleCode())) {
            throw new ResourceForbiddenException("Chỉ Listener được gửi câu trả lời.");
        }
        return user;
    }

    private ProducerProfile creator(UUID userId) {
        AppUser user = activeUser(userId);
        if (!"CREATOR".equals(user.getRole().getRoleCode())) {
            throw new ResourceForbiddenException("Chỉ Creator được quản lý poll.");
        }
        ProducerProfile profile = creators.findByUser_UserId(userId)
                .orElseThrow(() -> new ResourceForbiddenException("Tài khoản chưa có kênh Creator."));
        visibleCreator(profile);
        return profile;
    }

    private void apply(Poll poll, PollRequests.Write request) {
        Instant start = request.startsAt() == null ? Instant.now() : request.startsAt();
        if (request.endsAt() != null && !request.endsAt().isAfter(start)) {
            throw new InvalidFlowRequestException("endsAt phải lớn hơn startsAt.");
        }
        Set<String> distinct = new HashSet<>();
        for (String text : request.options()) {
            if (!distinct.add(text.trim().toLowerCase(Locale.ROOT))) {
                throw new InvalidFlowRequestException("Các option không được trùng nhau.");
            }
        }
        Series linkedSeries = null;
        if (request.seriesId() != null) {
            linkedSeries = series.findBySeriesIdAndProducerProfile_ProducerProfileId(
                    request.seriesId(), poll.getProducerProfile().getProducerProfileId())
                    .orElseThrow(() -> new ResourceNotFoundException("Series không thuộc kênh của bạn."));
            if ("ARCHIVED".equalsIgnoreCase(linkedSeries.getStatus())
                    || "DELETED".equalsIgnoreCase(linkedSeries.getStatus())) {
                throw new ResourceConflictException("Series đã được lưu trữ hoặc xóa.");
            }
        }
        Podcast linkedPodcast = null;
        if (request.podcastId() != null) {
            linkedPodcast = podcasts.findByPodcastIdAndProducerProfile_ProducerProfileId(
                    request.podcastId(), poll.getProducerProfile().getProducerProfileId())
                    .orElseThrow(() -> new ResourceNotFoundException("Podcast không thuộc kênh của bạn."));
            if ("DELETED".equalsIgnoreCase(linkedPodcast.getStatus())
                    || "ARCHIVED".equalsIgnoreCase(linkedPodcast.getStatus())) {
                throw new ResourceConflictException("Podcast đã được lưu trữ hoặc xóa.");
            }
        }
        poll.setSeries(linkedSeries);
        poll.setPodcast(linkedPodcast);
        poll.setQuestion(request.question().trim());
        poll.setStartsAt(start);
        poll.setEndsAt(request.endsAt());
    }

    private void saveOptions(Poll poll, List<String> texts) {
        for (int i = 0; i < texts.size(); i++) {
            PollOption option = new PollOption();
            option.setPoll(poll);
            option.setOptionText(texts.get(i).trim());
            option.setSortOrder(i + 1);
            options.save(option);
        }
    }

    private boolean isAccepting(Poll poll) {
        Instant now = Instant.now();
        return PollStatus.OPEN.name().equals(poll.getStatus()) && !poll.getStartsAt().isAfter(now)
                && (poll.getEndsAt() == null || poll.getEndsAt().isAfter(now));
    }

    private void accepting(Poll poll) {
        if (!isAccepting(poll)) {
            throw new ResourceConflictException("Poll chưa mở, đã đóng hoặc đã hết hạn trả lời.");
        }
    }

    private void requireStatus(Poll poll, PollStatus status) {
        if (!status.name().equals(poll.getStatus())) {
            throw new ResourceConflictException("Thao tác yêu cầu poll ở trạng thái " + status + ".");
        }
    }

    private Summary summary(Poll poll) {
        return new Summary(poll.getPollId(), poll.getProducerProfile().getProducerProfileId(),
                poll.getProducerProfile().getChannelName(), poll.getSeries() == null ? null : poll.getSeries().getSeriesId(),
                poll.getPodcast() == null ? null : poll.getPodcast().getPodcastId(),
                poll.getQuestion(), PollStatus.valueOf(poll.getStatus()), poll.getStartsAt(), poll.getEndsAt(),
                isAccepting(poll), poll.getCreatedAt(), poll.getUpdatedAt());
    }

    private Detail detail(Poll poll) {
        return new Detail(summary(poll), options.findAllByPoll_PollIdOrderBySortOrderAsc(poll.getPollId())
                .stream().map(o -> new Option(o.getPollOptionId(), o.getOptionText(), o.getSortOrder())).toList());
    }

    private Response response(PollVote vote) {
        return new Response(vote.getPollVoteId(), vote.getPoll().getPollId(), vote.getUser().getUserId(),
                vote.getUser().getDisplayName(), vote.getPollOption().getPollOptionId(),
                vote.getPollOption().getOptionText(), vote.getCreatedAt());
    }

    private Results results(Poll poll) {
        Map<UUID, Long> counts = new HashMap<>();
        votes.countOptions(poll.getPollId()).forEach(c -> counts.put(c.getOptionId(), c.getTotal()));
        long total = counts.values().stream().mapToLong(Long::longValue).sum();
        List<OptionResult> items = options.findAllByPoll_PollIdOrderBySortOrderAsc(poll.getPollId()).stream()
                .map(option -> {
                    long count = counts.getOrDefault(option.getPollOptionId(), 0L);
                    double percentage = total == 0 ? 0 : Math.round(count * 10000.0 / total) / 100.0;
                    return new OptionResult(option.getPollOptionId(), option.getOptionText(),
                            option.getSortOrder(), count, percentage);
                }).toList();
        return new Results(poll.getPollId(), poll.getQuestion(), total, items);
    }

    private Specification<Poll> filter(UUID creatorId, boolean published, PollStatus status,
            UUID seriesId, UUID podcastId) {
        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.equal(root.get("producerProfile").get("producerProfileId"), creatorId));
            predicates.add(cb.notEqual(root.get("status"), PollStatus.DELETED.name()));
            if (published) predicates.add(root.get("status").in(PollStatus.OPEN.name(), PollStatus.CLOSED.name()));
            if (status != null) predicates.add(cb.equal(root.get("status"), status.name()));
            if (seriesId != null) predicates.add(cb.equal(root.get("series").get("seriesId"), seriesId));
            if (podcastId != null) predicates.add(cb.equal(root.get("podcast").get("podcastId"), podcastId));
            return cb.and(predicates.toArray(Predicate[]::new));
        };
    }

    private Pageable page(int page, int size) {
        return PageRequest.of(Math.max(0, page), Math.min(100, Math.max(1, size)),
                Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("pollId")));
    }
}
