package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.response.CreatorDashboardResponse;
import com.prmteam7.podcasthistory.dto.response.CreatorDashboardResponse.GrowthPoint;
import com.prmteam7.podcasthistory.dto.response.CreatorDashboardResponse.Metrics;
import com.prmteam7.podcasthistory.dto.response.CreatorDashboardResponse.Profile;
import com.prmteam7.podcasthistory.dto.response.CreatorResponses.PodcastItem;
import com.prmteam7.podcasthistory.dto.response.SeriesRequestResponse;
import com.prmteam7.podcasthistory.exception.ResourceForbiddenException;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.ProducerProfile;
import com.prmteam7.podcasthistory.model.UserWallet;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.FollowRepository;
import com.prmteam7.podcasthistory.repository.ListeningHistoryRepository;
import com.prmteam7.podcasthistory.repository.PaymentRepository;
import com.prmteam7.podcasthistory.repository.PodcastRepository;
import com.prmteam7.podcasthistory.repository.PayoutPaymentRepository;
import com.prmteam7.podcasthistory.repository.ProducerProfileRepository;
import com.prmteam7.podcasthistory.repository.UserWalletRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CreatorDashboardService {

    private static final String DEFAULT_PERIOD = "7d";
    private static final String DEFAULT_CURRENCY = "USD";
    private static final BigDecimal ZERO = BigDecimal.ZERO.setScale(2);

    private final AppUserRepository userRepository;
    private final ProducerProfileRepository profileRepository;
    private final PodcastRepository podcastRepository;
    private final FollowRepository followRepository;
    private final ListeningHistoryRepository listeningHistoryRepository;
    private final PaymentRepository paymentRepository;
    private final PayoutPaymentRepository payoutPaymentRepository;
    private final UserWalletRepository walletRepository;
    private final CreatorFlowService creatorFlowService;
    private final PodcastRequestService podcastRequestService;

    public CreatorDashboardService(
            AppUserRepository userRepository,
            ProducerProfileRepository profileRepository,
            PodcastRepository podcastRepository,
            FollowRepository followRepository,
            ListeningHistoryRepository listeningHistoryRepository,
            PaymentRepository paymentRepository,
            PayoutPaymentRepository payoutPaymentRepository,
            UserWalletRepository walletRepository,
            CreatorFlowService creatorFlowService,
            PodcastRequestService podcastRequestService) {
        this.userRepository = userRepository;
        this.profileRepository = profileRepository;
        this.podcastRepository = podcastRepository;
        this.followRepository = followRepository;
        this.listeningHistoryRepository = listeningHistoryRepository;
        this.paymentRepository = paymentRepository;
        this.payoutPaymentRepository = payoutPaymentRepository;
        this.walletRepository = walletRepository;
        this.creatorFlowService = creatorFlowService;
        this.podcastRequestService = podcastRequestService;
    }

    @Transactional(readOnly = true)
    public CreatorDashboardResponse getDashboard(UUID userId, String requestedPeriod) {
        ProducerProfile profile = requireApprovedCreator(userId);
        UUID creatorId = profile.getProducerProfileId();
        String period = normalizePeriod(requestedPeriod);

        Instant now = Instant.now();
        YearMonth currentMonth = YearMonth.now(ZoneOffset.UTC);
        Instant monthFrom = currentMonth.atDay(1).atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant monthTo = currentMonth.plusMonths(1).atDay(1).atStartOfDay(ZoneOffset.UTC).toInstant();

        UserWallet wallet = walletRepository.findByUser_UserId(userId).orElse(null);
        String currency = wallet == null || wallet.getCurrency() == null
                ? DEFAULT_CURRENCY
                : wallet.getCurrency().trim().toUpperCase(Locale.ROOT);
        BigDecimal monthlyRevenue = money(paymentRepository.sumCreatorContractRevenue(
                creatorId, currency, monthFrom, monthTo))
                .add(money(paymentRepository.sumCreatorDisputeRevenue(
                        creatorId, currency, monthFrom, monthTo)))
                .add(money(paymentRepository.sumCreatorMembershipRevenue(
                        creatorId, currency, monthFrom, monthTo)));

        Metrics metrics = new Metrics(
                podcastRepository.countByProducerProfile_ProducerProfileId(creatorId),
                followRepository.countByProducerProfile_ProducerProfileId(creatorId),
                listeningHistoryRepository.countByCreator(creatorId),
                listeningHistoryRepository.countByCreatorBetween(creatorId, monthFrom, monthTo),
                monthlyRevenue,
                wallet == null ? ZERO : money(wallet.getBalance()),
                wallet == null
                        ? ZERO
                        : money(payoutPaymentRepository.sumPaidApprovedMilestonesPendingRelease(
                                userId, currency)),
                currency);

        List<PodcastItem> recentPodcasts = creatorFlowService.listPodcasts(userId).stream()
                .limit(5)
                .toList();
        List<SeriesRequestResponse> incomingRequests = podcastRequestService.getCreatorInbox(userId);

        return new CreatorDashboardResponse(
                toProfile(profile),
                metrics,
                buildGrowth(creatorId, period, now),
                recentPodcasts,
                incomingRequests);
    }

    private Profile toProfile(ProducerProfile profile) {
        AppUser user = profile.getUser();
        return new Profile(
                profile.getProducerProfileId(),
                user.getUserId(),
                user.getUsername(),
                user.getDisplayName(),
                profile.getChannelName(),
                profile.getDescription() == null ? user.getBio() : profile.getDescription(),
                profile.getAvatarUrl() == null ? user.getAvatarUrl() : profile.getAvatarUrl(),
                profile.getWebsiteUrl(),
                profile.getVerificationStatus(),
                Boolean.TRUE.equals(user.getIsVerified())
                        || "APPROVED".equalsIgnoreCase(profile.getVerificationStatus()));
    }

    private List<GrowthPoint> buildGrowth(UUID creatorId, String period, Instant now) {
        LocalDate today = now.atZone(ZoneOffset.UTC).toLocalDate();
        if ("12m".equals(period)) {
            YearMonth firstMonth = YearMonth.from(today).minusMonths(11);
            Instant from = firstMonth.atDay(1).atStartOfDay(ZoneOffset.UTC).toInstant();
            Instant to = YearMonth.from(today).plusMonths(1).atDay(1).atStartOfDay(ZoneOffset.UTC).toInstant();
            List<Instant> times = listeningHistoryRepository.findListenTimes(creatorId, from, to);
            Map<YearMonth, Long> counts = times.stream()
                    .map(time -> YearMonth.from(time.atZone(ZoneOffset.UTC)))
                    .collect(Collectors.groupingBy(Function.identity(), Collectors.counting()));
            List<GrowthPoint> result = new ArrayList<>();
            for (int index = 0; index < 12; index++) {
                YearMonth month = firstMonth.plusMonths(index);
                Instant pointFrom = month.atDay(1).atStartOfDay(ZoneOffset.UTC).toInstant();
                Instant pointTo = month.plusMonths(1).atDay(1).atStartOfDay(ZoneOffset.UTC).toInstant();
                result.add(new GrowthPoint(month.toString(), pointFrom, pointTo, counts.getOrDefault(month, 0L)));
            }
            return result;
        }

        int bucketCount = "4w".equals(period) ? 4 : 7;
        int days = bucketCount == 4 ? 28 : 7;
        LocalDate firstDay = today.minusDays(days - 1L);
        Instant from = firstDay.atStartOfDay(ZoneOffset.UTC).toInstant();
        Instant to = today.plusDays(1).atStartOfDay(ZoneOffset.UTC).toInstant();
        List<Instant> times = listeningHistoryRepository.findListenTimes(creatorId, from, to);
        Map<LocalDate, Long> counts = times.stream()
                .map(time -> time.atZone(ZoneOffset.UTC).toLocalDate())
                .collect(Collectors.groupingBy(Function.identity(), Collectors.counting()));
        List<GrowthPoint> result = new ArrayList<>();
        for (int index = 0; index < bucketCount; index++) {
            LocalDate pointFromDate = firstDay.plusDays(bucketCount == 4 ? index * 7L : index);
            LocalDate pointToDate = pointFromDate.plusDays(bucketCount == 4 ? 7L : 1L);
            long listens = 0L;
            for (int offset = 0; offset < (bucketCount == 4 ? 7 : 1); offset++) {
                listens += counts.getOrDefault(pointFromDate.plusDays(offset), 0L);
            }
            Instant pointFrom = pointFromDate.atStartOfDay(ZoneOffset.UTC).toInstant();
            Instant pointTo = pointToDate.atStartOfDay(ZoneOffset.UTC).toInstant();
            String label = bucketCount == 4
                    ? pointFromDate + " - " + pointToDate.minusDays(1)
                    : pointFromDate.toString();
            result.add(new GrowthPoint(label, pointFrom, pointTo, listens));
        }
        return result;
    }

    private ProducerProfile requireApprovedCreator(UUID userId) {
        AppUser user = userRepository.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản."));
        if (!Boolean.TRUE.equals(user.getIsActive())) {
            throw new ResourceForbiddenException("Tài khoản đã bị vô hiệu hóa.");
        }
        if (user.getRole() == null || !"CREATOR".equalsIgnoreCase(user.getRole().getRoleCode())) {
            throw new ResourceForbiddenException("Chỉ Content Creator mới được xem dashboard này.");
        }
        ProducerProfile profile = profileRepository.findByUser_UserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("Tài khoản chưa có hồ sơ Creator."));
        if (!"APPROVED".equalsIgnoreCase(profile.getVerificationStatus())) {
            throw new ResourceForbiddenException("Hồ sơ Creator chưa được Admin duyệt.");
        }
        return profile;
    }

    private String normalizePeriod(String requestedPeriod) {
        if (requestedPeriod == null || requestedPeriod.isBlank()) {
            return DEFAULT_PERIOD;
        }
        String period = requestedPeriod.trim().toLowerCase(Locale.ROOT);
        return switch (period) {
            case "7d", "4w", "12m" -> period;
            default -> DEFAULT_PERIOD;
        };
    }

    private BigDecimal money(BigDecimal value) {
        return value == null ? ZERO : value;
    }
}
