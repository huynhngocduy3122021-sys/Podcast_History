package com.prmteam7.podcasthistory.service;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.prmteam7.podcasthistory.dto.request.RecordPayoutResultRequest;
import com.prmteam7.podcasthistory.dto.request.RegisterVerifiedPayoutAccountRequest;
import com.prmteam7.podcasthistory.dto.request.WithdrawalRequestInput;
import com.prmteam7.podcasthistory.dto.response.PayoutAccountResponse;
import com.prmteam7.podcasthistory.dto.response.AdminWithdrawalResponse;
import com.prmteam7.podcasthistory.dto.response.ReleaseFundsResponse;
import com.prmteam7.podcasthistory.dto.response.WalletBalanceResponse;
import com.prmteam7.podcasthistory.dto.response.CreatorWalletTransactionItem;
import com.prmteam7.podcasthistory.dto.response.WithdrawalResponse;
import com.prmteam7.podcasthistory.enums.PayoutResult;
import com.prmteam7.podcasthistory.enums.UserRole;
import com.prmteam7.podcasthistory.enums.WithdrawalStatus;
import com.prmteam7.podcasthistory.exception.PodcastWorkflowNotFoundException;
import com.prmteam7.podcasthistory.exception.WalletWorkflowException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.Contract;
import com.prmteam7.podcasthistory.model.CreatorPayoutAccount;
import com.prmteam7.podcasthistory.model.Payment;
import com.prmteam7.podcasthistory.model.ProducerProfile;
import com.prmteam7.podcasthistory.model.UserWallet;
import com.prmteam7.podcasthistory.model.WalletTransaction;
import com.prmteam7.podcasthistory.model.WithdrawalRequest;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.CreatorPayoutAccountRepository;
import com.prmteam7.podcasthistory.repository.PayoutPaymentRepository;
import com.prmteam7.podcasthistory.repository.ProducerProfileRepository;
import com.prmteam7.podcasthistory.repository.UserWalletRepository;
import com.prmteam7.podcasthistory.repository.WalletTransactionRepository;
import com.prmteam7.podcasthistory.repository.WithdrawalRequestRepository;

@Service
public class CreatorWalletService {

    private static final BigDecimal ZERO = new BigDecimal("0.00");

    private final AppUserRepository userRepository;
    private final ProducerProfileRepository creatorRepository;
    private final UserWalletRepository walletRepository;
    private final CreatorPayoutAccountRepository payoutAccountRepository;
    private final WithdrawalRequestRepository withdrawalRepository;
    private final WalletTransactionRepository transactionRepository;
    private final PayoutPaymentRepository payoutPaymentRepository;

    public CreatorWalletService(
            AppUserRepository userRepository,
            ProducerProfileRepository creatorRepository,
            UserWalletRepository walletRepository,
            CreatorPayoutAccountRepository payoutAccountRepository,
            WithdrawalRequestRepository withdrawalRepository,
            WalletTransactionRepository transactionRepository,
            PayoutPaymentRepository payoutPaymentRepository) {
        this.userRepository = userRepository;
        this.creatorRepository = creatorRepository;
        this.walletRepository = walletRepository;
        this.payoutAccountRepository = payoutAccountRepository;
        this.withdrawalRepository = withdrawalRepository;
        this.transactionRepository = transactionRepository;
        this.payoutPaymentRepository = payoutPaymentRepository;
    }

    @Transactional(readOnly = true)
    public Page<CreatorWalletTransactionItem> transactions(UUID creatorUserId, String status, int page, int size) {
        requireCreator(creatorUserId);
        String normalizedStatus = status == null || status.isBlank() ? null : status.trim();
        Pageable pageable = PageRequest.of(Math.max(0, page), Math.min(100, Math.max(1, size)),
                Sort.by(Sort.Direction.DESC, "createdAt"));
        return transactionRepository.findForUser(creatorUserId, normalizedStatus, pageable)
                .map(transaction -> new CreatorWalletTransactionItem(
                        transaction.getWalletTransactionId(), transaction.getTransactionType(),
                        transaction.getDirection(), transaction.getAmount(), transaction.getCurrency(),
                        transaction.getStatus(), transaction.getReferenceCode(),
                        transaction.getBalanceAfter(), transaction.getHeldBalanceAfter(),
                        transaction.getCreatedAt()));
    }

    @Transactional
    public ReleaseFundsResponse releaseFunds(UUID creatorUserId) {
        ProducerProfile creator = requireCreator(creatorUserId);
        lockUser(creatorUserId);
        UserWallet wallet = getOrCreateWallet(creator);
        requireWalletActive(wallet);

        List<Payment> eligiblePayments = payoutPaymentRepository
                .findPaidApprovedMilestonesForRelease(creatorUserId);
        BigDecimal releasedAmount = ZERO;
        int releasedCount = 0;

        for (Payment payment : eligiblePayments) {
            if (transactionRepository.existsByPayment_PaymentIdAndTransactionType(
                    payment.getPaymentId(), "RELEASE_FUNDS")) {
                continue;
            }
            BigDecimal amount = money(payment.getAmount());
            if (amount.signum() <= 0) {
                throw new WalletWorkflowException("Payment nguồn có số tiền không hợp lệ.");
            }
            if (!wallet.getCurrency().equalsIgnoreCase(payment.getCurrency().trim())) {
                throw new WalletWorkflowException(
                        "Currency của Payment không khớp currency ví; không thể giải ngân tự động.");
            }

            wallet.setBalance(wallet.getBalance().add(amount));
            releasedAmount = releasedAmount.add(amount);
            releasedCount++;
            transactionRepository.save(createTransaction(
                    wallet, payment, null, "RELEASE_FUNDS", "CREDIT", amount,
                    "COMPLETED", wallet.getBalance(), wallet.getHeldBalance()));
        }
        walletRepository.save(wallet);
        return new ReleaseFundsResponse(
                releasedCount,
                releasedAmount,
                toBalanceResponse(wallet));
    }

    @Transactional
    public WalletBalanceResponse getBalance(UUID creatorUserId) {
        ProducerProfile creator = requireCreator(creatorUserId);
        lockUser(creatorUserId);
        return toBalanceResponse(getOrCreateWallet(creator));
    }

    @Transactional
    public WithdrawalResponse requestWithdrawal(UUID creatorUserId, WithdrawalRequestInput input) {
        ProducerProfile creator = requireCreator(creatorUserId);
        lockUser(creatorUserId);
        UserWallet wallet = getOrCreateWallet(creator);
        requireWalletActive(wallet);

        BigDecimal amount = money(input.amount());
        if (amount.signum() <= 0) {
            throw new WalletWorkflowException("Số tiền rút phải lớn hơn 0.");
        }
        if (amount.scale() > 2 || amount.precision() > 14) {
            throw new WalletWorkflowException("Số tiền rút tối đa 12 chữ số nguyên và 2 chữ số thập phân.");
        }
        if (wallet.getBalance().compareTo(amount) < 0) {
            throw new WalletWorkflowException("Số dư khả dụng không đủ để thực hiện yêu cầu rút tiền.");
        }

        CreatorPayoutAccount payoutAccount = payoutAccountRepository
                .findByCreatorPayoutAccountIdAndProducerProfile_ProducerProfileId(
                        input.payoutAccountId(), creator.getProducerProfileId())
                .filter(account -> Boolean.TRUE.equals(account.getActive())
                        && Boolean.TRUE.equals(account.getVerified()))
                .orElseThrow(() -> new WalletWorkflowException(
                        "Tài khoản nhận tiền không tồn tại, chưa xác minh hoặc không còn hoạt động."));
        if (!wallet.getCurrency().equalsIgnoreCase(payoutAccount.getCurrency().trim())) {
            throw new WalletWorkflowException("Currency tài khoản nhận tiền không khớp currency ví.");
        }

        wallet.setBalance(wallet.getBalance().subtract(amount));
        wallet.setHeldBalance(wallet.getHeldBalance().add(amount));
        walletRepository.save(wallet);

        WithdrawalRequest withdrawal = new WithdrawalRequest();
        withdrawal.setProducerProfile(creator);
        withdrawal.setUserWallet(wallet);
        withdrawal.setAmount(amount);
        withdrawal.setCurrency(wallet.getCurrency());
        withdrawal.setPayoutMethod(payoutAccount.getPayoutMethod());
        withdrawal.setPayoutAccountMasked(payoutAccount.getAccountMasked());
        withdrawal.setPayoutAccountReference(payoutAccount.getAccountReference());
        withdrawal.setStatus(WithdrawalStatus.PENDING.name());
        withdrawal.setRequestedAt(Instant.now());
        WithdrawalRequest savedWithdrawal = withdrawalRepository.save(withdrawal);

        transactionRepository.save(createTransaction(
                wallet, null, savedWithdrawal, "WITHDRAWAL_HOLD", "DEBIT", amount,
                "PENDING", wallet.getBalance(), wallet.getHeldBalance()));
        return toWithdrawalResponse(savedWithdrawal);
    }

    @Transactional(readOnly = true)
    public List<WithdrawalResponse> getWithdrawalHistory(UUID creatorUserId) {
        ProducerProfile creator = requireCreator(creatorUserId);
        return withdrawalRepository
                .findAllByProducerProfile_ProducerProfileIdOrderByRequestedAtDesc(
                        creator.getProducerProfileId())
                .stream().map(this::toWithdrawalResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<PayoutAccountResponse> getPayoutAccounts(UUID creatorUserId) {
        ProducerProfile creator = requireCreator(creatorUserId);
        return payoutAccountRepository
                .findAllByProducerProfile_ProducerProfileIdAndActiveTrueOrderByCreatedAtDesc(
                        creator.getProducerProfileId())
                .stream().map(this::toPayoutAccountResponse).toList();
    }

    @Transactional
    public WithdrawalResponse recordPayoutResult(
            UUID adminUserId, UUID withdrawalId, RecordPayoutResultRequest input) {
        if (input.result() == PayoutResult.SUCCESS && trimToNull(input.providerReference()) == null) {
            throw new WalletWorkflowException("Cần providerReference để ghi nhận payout thành công.");
        }
        AppUser admin = userRepository.findByIdForUpdate(adminUserId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy tài khoản Admin."));
        requireActive(admin);
        requireRole(admin, UserRole.ADMIN);

        WithdrawalRequest withdrawal = withdrawalRepository.findByIdForUpdate(withdrawalId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy yêu cầu rút tiền."));
        if (!WithdrawalStatus.PENDING.name().equals(withdrawal.getStatus())) {
            throw new WalletWorkflowException("Yêu cầu rút tiền này đã được xử lý.");
        }

        UserWallet wallet = walletRepository.findByUserIdForUpdate(
                        withdrawal.getProducerProfile().getUser().getUserId())
                .orElseThrow(() -> new WalletWorkflowException("Không tìm thấy ví Creator."));
        if (wallet.getHeldBalance().compareTo(withdrawal.getAmount()) < 0) {
            throw new WalletWorkflowException("Số dư đang giữ không khớp yêu cầu rút tiền.");
        }

        WalletTransaction holdTransaction = transactionRepository
                .findFirstByWithdrawalRequest_WithdrawalRequestIdAndTransactionType(
                        withdrawalId, "WITHDRAWAL_HOLD")
                .orElseThrow(() -> new WalletWorkflowException("Không tìm thấy giao dịch giữ tiền."));

        wallet.setHeldBalance(wallet.getHeldBalance().subtract(withdrawal.getAmount()));
        if (input.result() == PayoutResult.SUCCESS) {
            withdrawal.setStatus(WithdrawalStatus.COMPLETED.name());
            withdrawal.setProviderReference(trimToNull(input.providerReference()));
            withdrawal.setNote(trimToNull(input.note()));
            holdTransaction.setStatus("COMPLETED");
        } else {
            wallet.setBalance(wallet.getBalance().add(withdrawal.getAmount()));
            withdrawal.setStatus(WithdrawalStatus.FAILED.name());
            withdrawal.setNote(trimToNull(input.note()) == null
                    ? "Giao dịch chuyển tiền thất bại; tiền đã được hoàn lại vào số dư khả dụng."
                    : input.note().trim());
            holdTransaction.setStatus("FAILED");

            transactionRepository.save(createTransaction(
                    wallet, null, withdrawal, "WITHDRAWAL_REFUND", "CREDIT", withdrawal.getAmount(),
                    "COMPLETED", wallet.getBalance(), wallet.getHeldBalance()));
        }

        withdrawal.setProcessedAt(Instant.now());
        holdTransaction.setBalanceAfter(wallet.getBalance());
        holdTransaction.setHeldBalanceAfter(wallet.getHeldBalance());
        walletRepository.save(wallet);
        transactionRepository.save(holdTransaction);
        return toWithdrawalResponse(withdrawalRepository.save(withdrawal));
    }

    @Transactional(readOnly = true)
    public List<AdminWithdrawalResponse> getPendingWithdrawals(UUID adminUserId) {
        AppUser admin = userRepository.findById(adminUserId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy tài khoản Admin."));
        requireActive(admin);
        requireRole(admin, UserRole.ADMIN);
        return withdrawalRepository.findAllByStatusOrderByRequestedAtAsc(WithdrawalStatus.PENDING.name())
                .stream().map(this::toAdminWithdrawalResponse).toList();
    }

    @Transactional
    public PayoutAccountResponse registerVerifiedPayoutAccount(
            UUID adminUserId, UUID creatorProfileId, RegisterVerifiedPayoutAccountRequest input) {
        AppUser admin = userRepository.findByIdForUpdate(adminUserId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy tài khoản Admin."));
        requireActive(admin);
        requireRole(admin, UserRole.ADMIN);
        ProducerProfile creator = creatorRepository.findById(creatorProfileId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy hồ sơ Creator."));
        requireActive(creator.getUser());
        requireRole(creator.getUser(), UserRole.CREATOR);

        String accountReference = input.accountReference().trim();
        if (accountReference.isBlank()) {
            throw new WalletWorkflowException("Provider account reference không hợp lệ.");
        }

        CreatorPayoutAccount account = new CreatorPayoutAccount();
        account.setProducerProfile(creator);
        account.setPayoutMethod(input.payoutMethod().trim().toUpperCase(Locale.ROOT));
        account.setAccountReference(accountReference);
        account.setAccountMasked(input.accountMasked().trim());
        account.setCurrency(input.currency().trim().toUpperCase(Locale.ROOT));
        account.setVerified(true);
        account.setActive(true);
        account.setVerifiedAt(Instant.now());
        return toPayoutAccountResponse(payoutAccountRepository.save(account));
    }

    private AppUser lockUser(UUID userId) {
        AppUser user = userRepository.findByIdForUpdate(userId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy tài khoản Creator."));
        requireActive(user);
        requireRole(user, UserRole.CREATOR);
        return user;
    }

    private ProducerProfile requireCreator(UUID creatorUserId) {
        AppUser user = userRepository.findById(creatorUserId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy tài khoản Creator."));
        requireActive(user);
        requireRole(user, UserRole.CREATOR);
        return creatorRepository.findByUser_UserId(creatorUserId)
                .orElseThrow(() -> new WalletWorkflowException("Tài khoản Creator chưa có hồ sơ kênh."));
    }

    private UserWallet getOrCreateWallet(ProducerProfile creator) {
        return walletRepository.findByUserIdForUpdate(creator.getUser().getUserId())
                .orElseGet(() -> {
                    UserWallet wallet = new UserWallet();
                    wallet.setUser(creator.getUser());
                    wallet.setBalance(ZERO);
                    wallet.setHeldBalance(ZERO);
                    wallet.setCurrency("USD");
                    wallet.setStatus("ACTIVE");
                    return walletRepository.saveAndFlush(wallet);
                });
    }

    private WalletTransaction createTransaction(
            UserWallet wallet,
            Payment payment,
            WithdrawalRequest withdrawal,
            String type,
            String direction,
            BigDecimal amount,
            String status,
            BigDecimal availableAfter,
            BigDecimal heldAfter) {
        WalletTransaction transaction = new WalletTransaction();
        transaction.setUserWallet(wallet);
        transaction.setPayment(payment);
        transaction.setWithdrawalRequest(withdrawal);
        transaction.setTransactionType(type);
        transaction.setDirection(direction);
        transaction.setAmount(amount);
        transaction.setCurrency(wallet.getCurrency());
        transaction.setStatus(status);
        transaction.setBalanceAfter(availableAfter);
        transaction.setHeldBalanceAfter(heldAfter);
        return transaction;
    }

    private WalletBalanceResponse toBalanceResponse(UserWallet wallet) {
        BigDecimal available = wallet.getBalance() == null ? ZERO : wallet.getBalance();
        BigDecimal held = wallet.getHeldBalance() == null ? ZERO : wallet.getHeldBalance();
        BigDecimal pendingRelease = payoutPaymentRepository
                .sumPaidApprovedMilestonesPendingRelease(
                        wallet.getUser().getUserId(), wallet.getCurrency());
        return new WalletBalanceResponse(
                wallet.getUserWalletId(), available, held, available.add(held),
                pendingRelease == null ? ZERO : pendingRelease, wallet.getCurrency());
    }

    private WithdrawalResponse toWithdrawalResponse(WithdrawalRequest withdrawal) {
        return new WithdrawalResponse(
                withdrawal.getWithdrawalRequestId(),
                withdrawal.getAmount(),
                withdrawal.getCurrency(),
                withdrawal.getPayoutMethod(),
                withdrawal.getPayoutAccountMasked(),
                withdrawal.getProviderReference(),
                withdrawal.getStatus(),
                withdrawal.getRequestedAt(),
                withdrawal.getProcessedAt(),
                withdrawal.getNote());
    }

    private AdminWithdrawalResponse toAdminWithdrawalResponse(WithdrawalRequest withdrawal) {
        return new AdminWithdrawalResponse(
                withdrawal.getWithdrawalRequestId(),
                withdrawal.getProducerProfile().getProducerProfileId(),
                withdrawal.getAmount(),
                withdrawal.getCurrency(),
                withdrawal.getPayoutMethod(),
                withdrawal.getPayoutAccountMasked(),
                withdrawal.getPayoutAccountReference(),
                withdrawal.getStatus(),
                withdrawal.getRequestedAt(),
                withdrawal.getNote());
    }

    private PayoutAccountResponse toPayoutAccountResponse(CreatorPayoutAccount account) {
        return new PayoutAccountResponse(
                account.getCreatorPayoutAccountId(),
                account.getProducerProfile().getProducerProfileId(),
                account.getPayoutMethod(),
                account.getAccountMasked(),
                account.getCurrency(),
                Boolean.TRUE.equals(account.getVerified()),
                Boolean.TRUE.equals(account.getActive()));
    }

    private void requireWalletActive(UserWallet wallet) {
        if (!"ACTIVE".equalsIgnoreCase(wallet.getStatus())) {
            throw new WalletWorkflowException("Ví Creator hiện không hoạt động.");
        }
    }

    private void requireActive(AppUser user) {
        if (!Boolean.TRUE.equals(user.getIsActive())) {
            throw new WalletWorkflowException("Tài khoản hiện không hoạt động.");
        }
    }

    private void requireRole(AppUser user, UserRole role) {
        if (user.getRole() == null || !role.name().equalsIgnoreCase(user.getRole().getRoleCode())) {
            throw new WalletWorkflowException("Tài khoản không có quyền thực hiện thao tác này.");
        }
    }

    private BigDecimal money(BigDecimal amount) {
        return amount == null ? ZERO : amount;
    }

    private String trimToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
