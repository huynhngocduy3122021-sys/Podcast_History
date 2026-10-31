package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.request.ContractWorkflowRequests;
import com.prmteam7.podcasthistory.dto.response.ContractWorkflowResponses;
import com.prmteam7.podcasthistory.enums.ContractStageStatus;
import com.prmteam7.podcasthistory.enums.ListenerWinAction;
import com.prmteam7.podcasthistory.exception.PodcastWorkflowException;
import com.prmteam7.podcasthistory.exception.PodcastWorkflowNotFoundException;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ContractEscrowService {
    private static final BigDecimal ZERO = BigDecimal.ZERO.setScale(2);
    private static final BigDecimal PLATFORM_RATE = new BigDecimal("0.20");
    private static final BigDecimal COMPENSATION_RATE = new BigDecimal("0.30");
    private static final BigDecimal COMPENSATION_FEE_RATE = new BigDecimal("0.10");
    private final AppUserRepository users;
    private final ProducerProfileRepository creators;
    private final SeriesRequestRepository requests;
    private final RequestResponseRepository responses;
    private final ContractRepository contracts;
    private final ContractStageRepository stages;
    private final ContractEscrowRepository escrows;
    private final UserWalletRepository wallets;
    private final WalletTransactionRepository transactions;
    private final PaymentRepository payments;
    private final PaymentMethodRepository paymentMethods;
    private final ListenerWalletService listenerWallets;
    private final ContractDisputeRepository contractDisputes;
    private final MilestoneSubmissionRepository submissions;

    public ContractEscrowService(AppUserRepository users, ProducerProfileRepository creators,
            SeriesRequestRepository requests, RequestResponseRepository responses,
            ContractRepository contracts, ContractStageRepository stages,
            ContractEscrowRepository escrows, UserWalletRepository wallets,
            WalletTransactionRepository transactions, PaymentRepository payments,
            PaymentMethodRepository paymentMethods, ListenerWalletService listenerWallets,
            ContractDisputeRepository contractDisputes, MilestoneSubmissionRepository submissions) {
        this.users = users;
        this.creators = creators;
        this.requests = requests;
        this.responses = responses;
        this.contracts = contracts;
        this.stages = stages;
        this.escrows = escrows;
        this.wallets = wallets;
        this.transactions = transactions;
        this.payments = payments;
        this.paymentMethods = paymentMethods;
        this.listenerWallets = listenerWallets;
        this.contractDisputes = contractDisputes;
        this.submissions = submissions;
    }

    @Transactional
    public ContractWorkflowResponses.Request create(UUID listenerId, ContractWorkflowRequests.Create input) {
        if (input.budgetAmount() == null || input.budgetAmount().signum() <= 0
                || input.budgetAmount().scale() > 0)
            throw new PodcastWorkflowException("Ngân sách phải là VND nguyên dương.");
        AppUser listener = lockedActiveUser(listenerId, "LISTENER");
        var existing = escrows.findByIdempotencyKey(input.idempotencyKey());
        if (existing.isPresent()) {
            ContractEscrow saved = existing.get();
            if (!saved.getRequest().getUser().getUserId().equals(listenerId))
                throw new PodcastWorkflowException("Mã yêu cầu đã được tài khoản khác sử dụng.");
            if (!saved.getRequest().getProducerProfile().getProducerProfileId().equals(input.creatorProfileId())
                    || !saved.getRequest().getRequestedTitle().equals(input.requestedTitle().trim())
                    || !saved.getRequest().getDescription().equals(input.description().trim())
                    || saved.getBudget().compareTo(input.budgetAmount()) != 0
                    || !saved.getProductType().equals(input.productType())
                    || !saved.getFileFormat().equals(input.fileFormat().trim())
                    || !saved.getDurationDescription().equals(input.duration().trim())
                    || !saved.getAcceptanceCriteria().equals(input.acceptanceCriteria().trim())
                    || saved.isAutoAcceptEnabled() != input.autoAcceptEnabled())
                throw new PodcastWorkflowException("Mã yêu cầu đã dùng cho nội dung khác.");
            return new ContractWorkflowResponses.Request(saved.getRequest().getSeriesRequestId(),
                    saved.getRequest().getStatus(), saved.getBudget(),
                    saved.isFundsHeld() ? saved.getRemaining() : ZERO, "VND");
        }
        ProducerProfile creator = creators.findById(input.creatorProfileId())
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy kênh CC."));
        if (!"APPROVED".equalsIgnoreCase(creator.getVerificationStatus())
                || !Boolean.TRUE.equals(creator.getUser().getIsActive())
                || !"CREATOR".equalsIgnoreCase(creator.getUser().getRole().getRoleCode()))
            throw new PodcastWorkflowException("Kênh CC chưa được duyệt hoặc không hoạt động.");
        BigDecimal budget = input.budgetAmount().setScale(2);

        SeriesRequest request = new SeriesRequest();
        request.setUser(listener);
        request.setProducerProfile(creator);
        request.setRequestedTitle(input.requestedTitle().trim());
        request.setDescription(input.description().trim());
        request.setRequestFee(budget);
        request.setCurrency("VND");
        request.setStatus("PENDING");
        request = requests.saveAndFlush(request);

        ContractEscrow escrow = new ContractEscrow();
        escrow.setRequest(request);
        escrow.setIdempotencyKey(input.idempotencyKey());
        escrow.setBudget(budget);
        escrow.setRemaining(budget);
        escrow.setFundsHeld(false);
        escrow.setProductType(input.productType());
        escrow.setFileFormat(input.fileFormat().trim());
        escrow.setDurationDescription(input.duration().trim());
        escrow.setAcceptanceCriteria(input.acceptanceCriteria().trim());
        escrow.setAutoAcceptEnabled(input.autoAcceptEnabled());
        escrows.save(escrow);
        return new ContractWorkflowResponses.Request(request.getSeriesRequestId(), request.getStatus(), budget, ZERO, "VND");
    }

    @Transactional
    public ContractWorkflowResponses.Agreement propose(UUID creatorUserId, UUID requestId,
            ContractWorkflowRequests.Proposal input) {
        if (input.milestones() == null || input.milestones().isEmpty())
            throw new PodcastWorkflowException("Hợp đồng phải có ít nhất một đợt.");
        lockedActiveUser(creatorUserId, "CREATOR");
        SeriesRequest request = lockedRequest(requestId);
        if (!request.getProducerProfile().getUser().getUserId().equals(creatorUserId))
            throw new PodcastWorkflowException("Yêu cầu không thuộc kênh CC này.");
        ContractEscrow escrow = lockEscrow(requestId);
        if (!"PENDING".equals(request.getStatus()) || escrow.getContract() != null)
            throw new PodcastWorkflowException("Yêu cầu này đã được xử lý.");
        if (input.milestones().stream().anyMatch(s -> s.amount() == null
                || s.amount().signum() <= 0 || s.amount().scale() > 0))
            throw new PodcastWorkflowException("Tiền từng đợt phải là VND nguyên dương.");
        BigDecimal total = input.milestones().stream().map(ContractWorkflowRequests.Stage::amount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        if (total.compareTo(escrow.getBudget()) != 0)
            throw new PodcastWorkflowException("Tổng tiền các đợt phải bằng đúng ngân sách Listener đã đề xuất.");
        Instant now = Instant.now();
        Instant previousDueAt = now;
        for (var stage : input.milestones()) {
            if (!stage.dueAt().isAfter(previousDueAt))
                throw new PodcastWorkflowException("Hạn nộp các đợt phải tăng dần và ở tương lai.");
            previousDueAt = stage.dueAt();
        }

        if (!escrow.isFundsHeld()) {
            AppUser listener = lockedActiveUser(request.getUser().getUserId(), "LISTENER");
            UserWallet wallet = listenerWallets.walletForLockedUser(listener);
            if (wallet.getBalance().compareTo(escrow.getBudget()) < 0)
                throw new PodcastWorkflowException("Số dư ví Listener không đủ để CC chấp nhận yêu cầu.");
            wallet.setBalance(wallet.getBalance().subtract(escrow.getBudget()));
            wallet.setHeldBalance(wallet.getHeldBalance().add(escrow.getBudget()));
            wallets.save(wallet);
            record(wallet, null, "CONTRACT_HOLD", "DEBIT", escrow.getBudget(),
                    "CONTRACT_HOLD:" + requestId);
            escrow.setFundsHeld(true);
        }

        RequestResponse response = new RequestResponse();
        response.setSeriesRequest(request);
        response.setProducerProfile(request.getProducerProfile());
        response.setResponseText(input.responseText().trim());
        response.setResponseStatus("ACCEPTED");
        response = responses.save(response);
        Contract contract = new Contract();
        contract.setUser(request.getUser());
        contract.setProducerProfile(request.getProducerProfile());
        contract.setSeriesResponse(response);
        contract.setStatus("PENDING_SIGNATURE");
        contract = contracts.saveAndFlush(contract);

        int order = 1;
        for (var offer : input.milestones()) {
            ContractStage stage = new ContractStage();
            stage.setContract(contract);
            stage.setStageName(offer.name().trim());
            stage.setDescription(offer.description().trim());
            stage.setStageOrder(order++);
            stage.setDueAt(offer.dueAt());
            stage.setAmount(offer.amount().setScale(2));
            stage.setStatus(ContractStageStatus.NOT_STARTED.name());
            stages.save(stage);
        }

        escrow.setContract(contract);
        escrow.setContractVersion(4);
        escrow.setContentSnapshot(renderSnapshot(escrow, input.milestones()));
        escrow.setContentHash(sha256(escrow.getContentSnapshot()));
        escrows.save(escrow);
        request.setStatus("ACCEPTED");
        request.setRespondedAt(now);
        requests.save(request);
        return view(escrow);
    }

    @Transactional(readOnly = true)
    public List<ContractWorkflowResponses.RequestDetail> getCreatorContractRequests(UUID creatorUserId) {
        activeUser(creatorUserId, "CREATOR");
        return escrows.findAllForCreator(creatorUserId).stream().map(this::requestDetail).toList();
    }

    @Transactional(readOnly = true)
    public ContractWorkflowResponses.RequestDetail getRequestDetail(UUID actorId, UUID requestId) {
        ContractEscrow escrow = escrows.findByRequest_SeriesRequestId(requestId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy yêu cầu có giữ tiền."));
        requireParticipant(escrow, actorId);
        activeUser(actorId, actorId.equals(escrow.getRequest().getUser().getUserId())
                ? "LISTENER" : "CREATOR");
        return requestDetail(escrow);
    }

    private ContractWorkflowResponses.RequestDetail requestDetail(ContractEscrow escrow) {
        SeriesRequest request = escrow.getRequest();
        UUID requestId = request.getSeriesRequestId();
        return new ContractWorkflowResponses.RequestDetail(requestId,
                request.getProducerProfile().getProducerProfileId(), request.getStatus(),
                request.getRequestedTitle(), request.getDescription(), escrow.getBudget(),
                escrow.isFundsHeld() ? escrow.getRemaining() : ZERO,
                escrow.isFundsHeld(), "VND", escrow.getProductType(), escrow.getFileFormat(),
                escrow.getDurationDescription(), escrow.getAcceptanceCriteria(),
                escrow.isAutoAcceptEnabled(), request.getCreatedAt());
    }

    @Transactional(readOnly = true)
    public ContractWorkflowResponses.Agreement getAgreement(UUID actorId, UUID requestId) {
        ContractEscrow escrow = escrows.findByRequest_SeriesRequestId(requestId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy hợp đồng giữ tiền."));
        requireParticipant(escrow, actorId);
        if (escrow.getContract() == null)
            throw new PodcastWorkflowException("CC chưa gửi đề xuất hợp đồng.");
        return view(escrow);
    }

    @Transactional
    public ContractWorkflowResponses.Agreement sign(UUID actorId, UUID requestId,
            ContractWorkflowRequests.Sign input) {
        if (!input.accepted())
            throw new PodcastWorkflowException("Cần xác nhận đã đọc và đồng ý hợp đồng.");
        lockedRequest(requestId);
        ContractEscrow escrow = lockEscrow(requestId);
        requireParticipant(escrow, actorId);
        activeUser(actorId, actorId.equals(escrow.getRequest().getUser().getUserId())
                ? "LISTENER" : "CREATOR");
        Contract contract = escrow.getContract();
        if (contract == null || !("PENDING_SIGNATURE".equals(contract.getStatus())
                || "IN_PROGRESS".equals(contract.getStatus())))
            throw new PodcastWorkflowException("Hợp đồng chưa sẵn sàng ký.");
        if (!escrow.isFundsHeld())
            throw new PodcastWorkflowException("Ngân sách của hợp đồng chưa được giữ.");
        if (!escrow.getContractVersion().equals(input.contractVersion())
                || !escrow.getContentHash().equalsIgnoreCase(input.contentHash()))
            throw new PodcastWorkflowException("Phiên bản hoặc hash hợp đồng không khớp bản đã xem.");
        Instant now = Instant.now();
        if (actorId.equals(contract.getUser().getUserId())) {
            if (escrow.getListenerSignedAt() == null) escrow.setListenerSignedAt(now);
        } else if (escrow.getCreatorSignedAt() == null) {
            escrow.setCreatorSignedAt(now);
        }
        if (escrow.getListenerSignedAt() != null && escrow.getCreatorSignedAt() != null) {
            UserWallet wallet = listenerWallets.walletForLockedUser(lockedActiveUser(
                    contract.getUser().getUserId(), "LISTENER"));
            if (wallet.getHeldBalance().compareTo(escrow.getRemaining()) < 0)
                throw new PodcastWorkflowException("Ngân sách giữ trong ví không còn đủ để kích hoạt hợp đồng.");
            contract.setStatus("IN_PROGRESS");
            contracts.save(contract);
        }
        escrows.save(escrow);
        return view(escrow);
    }

    @Transactional
    public ContractWorkflowResponses.Request cancel(UUID listenerId, UUID requestId) {
        SeriesRequest request = lockedRequest(requestId);
        ContractEscrow escrow = lockEscrow(requestId);
        if (!request.getUser().getUserId().equals(listenerId))
            throw new PodcastWorkflowException("Chỉ Listener tạo yêu cầu được hủy.");
        boolean beforeProposal = "PENDING".equals(request.getStatus()) && escrow.getContract() == null;
        boolean unactivatedProposal = "ACCEPTED".equals(request.getStatus())
                && escrow.getContract() != null
                && "PENDING_SIGNATURE".equals(escrow.getContract().getStatus());
        if (!beforeProposal && !unactivatedProposal)
            throw new PodcastWorkflowException("Chỉ hủy được yêu cầu trước khi cả hai bên ký và kích hoạt hợp đồng.");
        refundAll(escrow, "CONTRACT_CANCEL_REFUND:");
        if (unactivatedProposal) {
            Contract contract = escrow.getContract();
            contract.setStatus("CANCELLED");
            contracts.save(contract);
            List<ContractStage> contractStages = stages.findAllByContract_ContractIdOrderByStageOrder(contract.getContractId());
            contractStages.forEach(stage -> stage.setStatus("CANCELLED"));
            stages.saveAll(contractStages);
        }
        request.setStatus("CANCELLED");
        requests.save(request);
        return new ContractWorkflowResponses.Request(requestId, request.getStatus(), escrow.getBudget(), ZERO, "VND");
    }

    @Transactional
    public void refundRejectedRequest(SeriesRequest request) {
        escrows.lockByRequestId(request.getSeriesRequestId()).ifPresent(
                escrow -> refundAll(escrow, "CONTRACT_REJECT_REFUND:"));
    }

    @Transactional(readOnly = true)
    public ContractWorkflowResponses.TerminationRequestStatus getTerminationRequest(UUID actorId, UUID requestId) {
        ContractEscrow escrow = escrows.findByRequest_SeriesRequestId(requestId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy hợp đồng giữ tiền."));
        requireParticipant(escrow, actorId);
        if (escrow.getContract() == null)
            throw new PodcastWorkflowException("Hợp đồng chưa được CC đề xuất.");
        ContractDispute dispute = contractDisputes.findFirstByContract_ContractIdOrderByCreatedAtDesc(
                escrow.getContract().getContractId())
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Chưa có yêu cầu chấm dứt."));
        return new ContractWorkflowResponses.TerminationRequestStatus(dispute.getDisputeId(),
                escrow.getContract().getContractId(), dispute.getStatus(), dispute.getDecision(),
                dispute.getCreatedAt(), dispute.getCreatedAt().plus(3, ChronoUnit.DAYS),
                dispute.getResolvedAt(), dispute.getOpponentConfirmedAt(),
                dispute.getListenerWinAction() == null ? null : dispute.getListenerWinAction().name());
    }

    @Transactional
    public ContractWorkflowResponses.Termination terminate(UUID adminId, UUID contractId,
            ContractWorkflowRequests.Terminate input) {
        AppUser reviewer = users.findByIdForUpdate(adminId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy tài khoản xử lý tranh chấp."));
        if (!Boolean.TRUE.equals(reviewer.getIsActive()) || reviewer.getRole() == null
                || !("STAFF".equalsIgnoreCase(reviewer.getRole().getRoleCode())
                || "ADMIN".equalsIgnoreCase(reviewer.getRole().getRoleCode())))
            throw new PodcastWorkflowException("Chỉ Staff hoặc Admin được xử lý tranh chấp.");
        Contract contract = contracts.lockById(contractId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy hợp đồng."));
        if (!"DISPUTED".equals(contract.getStatus()))
            throw new PodcastWorkflowException("Hợp đồng cần có yêu cầu chấm dứt/tranh chấp đang mở.");
        ContractDispute dispute = contractDisputes.findFirstByContract_ContractIdAndStatus(contractId, "OPEN")
                .orElseThrow(() -> new PodcastWorkflowException("Không tìm thấy hồ sơ tranh chấp đang mở."));
        dispute = contractDisputes.lockById(dispute.getDisputeId()).orElseThrow();
        if (dispute.getOpponentConfirmedAt() != null)
            throw new PodcastWorkflowException("Tranh chấp đã xác nhận phải dùng quyết định thắng/thua của Staff.");
        if (dispute.getCreatedAt().plus(3, ChronoUnit.DAYS).isAfter(Instant.now()))
            throw new PodcastWorkflowException("Chưa hết 3 ngày ưu tiên thương lượng tranh chấp.");
        List<ContractStage> allStages = stages.lockAllByContractId(contractId);
        ContractEscrow escrow = escrows.lockByContractId(contractId)
                .orElseThrow(() -> new PodcastWorkflowException("Hợp đồng không có ngân sách giữ."));
        if (!escrow.isFundsHeld())
            throw new PodcastWorkflowException("Ngân sách của hợp đồng chưa được giữ.");
        ContractStage current = allStages.stream()
                .filter(s -> !ContractStageStatus.APPROVED.name().equals(s.getStatus()))
                .findFirst().orElse(null);
        BigDecimal compensation = ZERO;
        BigDecimal fee = ZERO;
        BigDecimal net = ZERO;
        if (input.compensateCurrentStage()) {
            if (current == null || input.qualifyingSubmissionId() == null
                    || input.evidenceNote() == null || input.evidenceNote().isBlank())
                throw new PodcastWorkflowException("Cần bản bàn giao và bằng chứng đạt tiêu chí tối thiểu để xét đền công.");
            MilestoneSubmission qualifying = submissions.findById(input.qualifyingSubmissionId())
                    .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy bản bàn giao làm bằng chứng."));
            if (!qualifying.getContractStage().getContractStageId().equals(current.getContractStageId()))
                throw new PodcastWorkflowException("Chưa có sản phẩm đợt hiện tại để xét đền công.");
            if (payments.findFirstByContractStage_ContractStageId(current.getContractStageId()).isPresent())
                throw new PodcastWorkflowException("Đợt hiện tại đã có Payment; cần đối soát trước khi đền công.");
            compensation = current.getAmount().multiply(COMPENSATION_RATE)
                    .setScale(0, RoundingMode.HALF_UP).setScale(2);
            if (compensation.signum() <= 0 || escrow.getRemaining().compareTo(compensation) < 0)
                throw new PodcastWorkflowException("Khoản đền công không hợp lệ hoặc vượt tiền đang giữ.");
            fee = compensation.multiply(COMPENSATION_FEE_RATE)
                    .setScale(0, RoundingMode.HALF_UP).setScale(2);
            net = compensation.subtract(fee);
            AppUser listener = lockedActiveUser(contract.getUser().getUserId(), "LISTENER");
            UserWallet listenerWallet = listenerWallets.walletForLockedUser(listener);
            if (listenerWallet.getHeldBalance().compareTo(compensation) < 0)
                throw new PodcastWorkflowException("Số dư giữ không đủ để trả đền công.");
            AppUser creator = lockedActiveUser(contract.getProducerProfile().getUser().getUserId(), "CREATOR");
            UserWallet creatorWallet = creatorWallet(creator);
            Payment payment = new Payment();
            payment.setUser(listener);
            payment.setContractStage(current);
            payment.setAmount(compensation);
            payment.setCurrency("VND");
            payment.setPaymentMethod("WALLET_ESCROW_COMPENSATION");
            payment.setStatus("PAID");
            payment.setPaidAt(Instant.now());
            payment = payments.saveAndFlush(payment);
            PaymentMethod method = new PaymentMethod();
            method.setPayment(payment);
            method.setMethodCode("WALLET_ESCROW_COMPENSATION");
            method.setDisplayName("Contract escrow compensation");
            method.setIsActive(true);
            paymentMethods.save(method);
            listenerWallet.setHeldBalance(listenerWallet.getHeldBalance().subtract(compensation));
            creatorWallet.setBalance(creatorWallet.getBalance().add(net));
            escrow.setRemaining(escrow.getRemaining().subtract(compensation));
            wallets.save(listenerWallet);
            wallets.save(creatorWallet);
            record(listenerWallet, payment, "CONTRACT_COMPENSATION_DEBIT", "DEBIT", compensation,
                    "CONTRACT_COMPENSATION:" + contractId);
            record(creatorWallet, payment, "RELEASE_FUNDS", "CREDIT", net,
                    "CONTRACT_COMPENSATION_CREATOR:" + contractId);
            if (fee.signum() > 0)
                record(null, payment, "PLATFORM_FEE", "CREDIT", fee,
                        "CONTRACT_COMPENSATION_FEE:" + contractId);
        }
        BigDecimal refund = escrow.getRemaining();
        refundAll(escrow, "CONTRACT_TERMINATION_REFUND:");
        for (ContractStage stage : allStages) {
            if (!ContractStageStatus.APPROVED.name().equals(stage.getStatus()))
                stage.setStatus("CANCELLED");
        }
        stages.saveAll(allStages);
        contract.setStatus("TERMINATED");
        contracts.save(contract);
        escrow.setTerminatedAt(Instant.now());
        escrows.save(escrow);
        dispute.setStatus("RESOLVED");
        dispute.setDecision(input.compensateCurrentStage() ? "TERMINATE_COMPENSATED" : "TERMINATE_REFUNDED");
        dispute.setReviewer(reviewer);
        dispute.setNote(input.reason().trim() + (input.compensateCurrentStage()
                ? "\nBản bàn giao: " + input.qualifyingSubmissionId()
                + "\nBằng chứng: " + input.evidenceNote().trim() : ""));
        dispute.setResolvedAt(Instant.now());
        contractDisputes.save(dispute);
        return new ContractWorkflowResponses.Termination(contractId, compensation, net, fee,
                refund, contract.getStatus());
    }

    @Transactional
    public ContractWorkflowResponses.Settlement settle(ContractStage stage) {
        UUID contractId = stage.getContract().getContractId();
        ContractEscrow escrow = escrows.lockByContractId(contractId)
                .orElseThrow(() -> new PodcastWorkflowException("Đợt này không thuộc hợp đồng giữ tiền."));
        if (!escrow.isFundsHeld())
            throw new PodcastWorkflowException("Ngân sách của hợp đồng chưa được giữ.");
        if (!"IN_PROGRESS".equals(stage.getContract().getStatus())
                || escrow.getCreatorSignedAt() == null || escrow.getListenerSignedAt() == null)
            throw new PodcastWorkflowException("Hợp đồng chưa được hai bên ký hoặc đang tranh chấp.");
        if (!ContractStageStatus.SUBMITTED.name().equals(stage.getStatus())
                && !ContractStageStatus.DISPUTED.name().equals(stage.getStatus()))
            throw new PodcastWorkflowException("Đợt không ở trạng thái chờ nghiệm thu.");
        if (payments.findFirstByContractStage_ContractStageId(stage.getContractStageId()).isPresent())
            throw new PodcastWorkflowException("Đợt này đã có Payment; không giải ngân lần hai.");
        BigDecimal gross = stage.getAmount();
        if (escrow.getRemaining().compareTo(gross) < 0)
            throw new PodcastWorkflowException("Số tiền giữ của hợp đồng không đủ cho đợt này.");
        AppUser listener = lockedActiveUser(stage.getContract().getUser().getUserId(), "LISTENER");
        UserWallet listenerWallet = listenerWallets.walletForLockedUser(listener);
        if (listenerWallet.getHeldBalance().compareTo(gross) < 0)
            throw new PodcastWorkflowException("Số dư đang giữ trong ví không khớp giá trị đợt.");
        AppUser creator = lockedActiveUser(stage.getContract().getProducerProfile().getUser().getUserId(), "CREATOR");
        UserWallet creatorWallet = creatorWallet(creator);
        BigDecimal fee = gross.multiply(PLATFORM_RATE).setScale(0, RoundingMode.HALF_UP).setScale(2);
        BigDecimal net = gross.subtract(fee);

        Payment payment = new Payment();
        payment.setUser(listener);
        payment.setContractStage(stage);
        payment.setAmount(gross);
        payment.setCurrency("VND");
        payment.setPaymentMethod("WALLET_ESCROW");
        payment.setStatus("PAID");
        payment.setPaidAt(Instant.now());
        payment = payments.saveAndFlush(payment);
        PaymentMethod method = new PaymentMethod();
        method.setPayment(payment);
        method.setMethodCode("WALLET_ESCROW");
        method.setDisplayName("Listener contract escrow");
        method.setIsActive(true);
        paymentMethods.save(method);

        listenerWallet.setHeldBalance(listenerWallet.getHeldBalance().subtract(gross));
        creatorWallet.setBalance(creatorWallet.getBalance().add(net));
        escrow.setRemaining(escrow.getRemaining().subtract(gross));
        wallets.save(listenerWallet);
        wallets.save(creatorWallet);
        escrows.save(escrow);
        record(listenerWallet, payment, "CONTRACT_STAGE_DEBIT", "DEBIT", gross,
                "CONTRACT_STAGE:" + stage.getContractStageId());
        record(creatorWallet, payment, "RELEASE_FUNDS", "CREDIT", net,
                "CONTRACT_CREATOR:" + stage.getContractStageId());
        if (fee.signum() > 0)
            record(null, payment, "PLATFORM_FEE", "CREDIT", fee,
                    "CONTRACT_FEE:" + stage.getContractStageId());
        return new ContractWorkflowResponses.Settlement(stage.getContractStageId(), payment.getPaymentId(),
                gross, net, fee, escrow.getRemaining(), "PAID");
    }

    private UserWallet creatorWallet(AppUser creator) {
        UserWallet wallet = wallets.findByUserIdForUpdate(creator.getUserId()).orElseGet(() -> {
            UserWallet created = new UserWallet();
            created.setUser(creator);
            created.setBalance(ZERO);
            created.setHeldBalance(ZERO);
            created.setCurrency("VND");
            created.setStatus("ACTIVE");
            return wallets.saveAndFlush(created);
        });
        if (!"ACTIVE".equalsIgnoreCase(wallet.getStatus()))
            throw new PodcastWorkflowException("Ví CC không hoạt động.");
        if (!"VND".equalsIgnoreCase(wallet.getCurrency().trim())) {
            if (wallet.getBalance().signum() != 0 || wallet.getHeldBalance().signum() != 0)
                throw new PodcastWorkflowException("Ví CC đang dùng tiền tệ khác VND; cần đối soát trước khi nhận tiền.");
            wallet.setCurrency("VND");
            wallets.save(wallet);
        }
        return wallet;
    }

    public boolean isEscrowRequest(UUID requestId) {
        return escrows.findByRequest_SeriesRequestId(requestId).isPresent();
    }

    public boolean isEscrowContract(Contract contract) {
        return escrows.findByContract_ContractId(contract.getContractId()).isPresent();
    }

    public boolean autoAcceptEnabled(Contract contract) {
        return escrows.findByContract_ContractId(contract.getContractId())
                .map(ContractEscrow::isAutoAcceptEnabled).orElse(false);
    }

    public void requireActiveSigned(Contract contract) {
        var escrow = escrows.findByContract_ContractId(contract.getContractId());
        if (escrow.isPresent() && (!"IN_PROGRESS".equals(contract.getStatus())
                || escrow.get().getCreatorSignedAt() == null || escrow.get().getListenerSignedAt() == null))
            throw new PodcastWorkflowException("Hợp đồng chưa được hai bên ký và kích hoạt.");
    }

    public void requirePreviousStagesApproved(ContractStage stage) {
        if (!isEscrowContract(stage.getContract())) return;
        for (ContractStage previous : stages.findAllByContract_ContractIdOrderByStageOrder(
                stage.getContract().getContractId())) {
            if (previous.getStageOrder() >= stage.getStageOrder()) break;
            if (!ContractStageStatus.APPROVED.name().equals(previous.getStatus())
                    && !ContractStageStatus.SKIPPED_REFUNDED.name().equals(previous.getStatus()))
                throw new PodcastWorkflowException("Cần nghiệm thu đợt trước trước khi bàn giao đợt này.");
        }
    }

    @Transactional
    public BigDecimal resolveListenerWin(UUID contractId, ListenerWinAction action, UUID stageId) {
        if (action == null) throw new PodcastWorkflowException("Listener chưa chọn cách xử lý khi thắng.");
        Contract contract = contracts.lockById(contractId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy hợp đồng."));
        ContractEscrow escrow = escrows.lockByContractId(contractId)
                .orElseThrow(() -> new PodcastWorkflowException("Hợp đồng không có ngân sách giữ."));
        if (!escrow.isFundsHeld()) throw new PodcastWorkflowException("Ngân sách chưa được giữ.");
        List<ContractStage> all = stages.lockAllByContractId(contractId);
        if (action == ListenerWinAction.CANCEL_CONTRACT) {
            BigDecimal refund = escrow.getRemaining();
            refundAll(escrow, "CONTRACT_DISPUTE_REFUND:");
            all.stream().filter(s -> !ContractStageStatus.APPROVED.name().equals(s.getStatus()))
                    .forEach(s -> s.setStatus("CANCELLED"));
            stages.saveAll(all);
            contract.setStatus("TERMINATED");
            escrow.setTerminatedAt(Instant.now());
            contracts.save(contract);
            escrows.save(escrow);
            return refund;
        }
        ContractStage current = all.stream()
                .filter(s -> stageId == null || stageId.equals(s.getContractStageId()))
                .filter(s -> !ContractStageStatus.APPROVED.name().equals(s.getStatus())
                        && !ContractStageStatus.SKIPPED_REFUNDED.name().equals(s.getStatus()))
                .findFirst().orElseThrow(() -> new PodcastWorkflowException("Không tìm thấy đợt có thể hoàn tiền."));
        if (payments.findFirstByContractStage_ContractStageId(current.getContractStageId()).isPresent())
            throw new PodcastWorkflowException("Đợt này đã được thanh toán; không thể hoàn lần nữa.");
        BigDecimal refund = current.getAmount();
        if (escrow.getRemaining().compareTo(refund) < 0)
            throw new PodcastWorkflowException("Tiền giữ của hợp đồng không đủ để hoàn đợt.");
        AppUser listener = lockedActiveUser(contract.getUser().getUserId(), "LISTENER");
        UserWallet wallet = listenerWallets.walletForLockedUser(listener);
        if (wallet.getHeldBalance().compareTo(refund) < 0)
            throw new PodcastWorkflowException("Số dư đang giữ không đủ để hoàn đợt.");
        wallet.setHeldBalance(wallet.getHeldBalance().subtract(refund));
        wallet.setBalance(wallet.getBalance().add(refund));
        escrow.setRemaining(escrow.getRemaining().subtract(refund));
        current.setStatus(ContractStageStatus.SKIPPED_REFUNDED.name());
        wallets.save(wallet);
        stages.save(current);
        escrows.save(escrow);
        record(wallet, null, "CONTRACT_STAGE_REFUND", "CREDIT", refund,
                "CONTRACT_STAGE_REFUND:" + current.getContractStageId());
        boolean finished = all.stream().allMatch(s -> ContractStageStatus.APPROVED.name().equals(s.getStatus())
                || ContractStageStatus.SKIPPED_REFUNDED.name().equals(s.getStatus()));
        contract.setStatus(finished ? "COMPLETED" : "IN_PROGRESS");
        contracts.save(contract);
        return refund;
    }

    private void refundAll(ContractEscrow escrow, String prefix) {
        if (escrow.getRemaining().signum() <= 0) return;
        if (!escrow.isFundsHeld()) {
            escrow.setRemaining(ZERO);
            escrows.save(escrow);
            return;
        }
        AppUser listener = lockedActiveUser(escrow.getRequest().getUser().getUserId(), "LISTENER");
        UserWallet wallet = listenerWallets.walletForLockedUser(listener);
        BigDecimal amount = escrow.getRemaining();
        if (wallet.getHeldBalance().compareTo(amount) < 0)
            throw new PodcastWorkflowException("Số dư đang giữ không khớp khoản cần hoàn.");
        wallet.setHeldBalance(wallet.getHeldBalance().subtract(amount));
        wallet.setBalance(wallet.getBalance().add(amount));
        escrow.setRemaining(ZERO);
        wallets.save(wallet);
        escrows.save(escrow);
        record(wallet, null, "CONTRACT_REFUND", "CREDIT", amount,
                prefix + escrow.getRequest().getSeriesRequestId());
    }

    private ContractWorkflowResponses.Agreement view(ContractEscrow escrow) {
        Contract contract = escrow.getContract();
        List<ContractWorkflowResponses.Stage> items = stages
                .findAllByContract_ContractIdOrderByStageOrder(contract.getContractId()).stream()
                .map(s -> new ContractWorkflowResponses.Stage(s.getContractStageId(), s.getStageName(),
                        s.getDescription(), s.getDueAt(), s.getAmount(), s.getStatus())).toList();
        return new ContractWorkflowResponses.Agreement(escrow.getRequest().getSeriesRequestId(),
                contract.getContractId(), contract.getStatus(), escrow.getContractVersion(),
                escrow.getContentHash(), escrow.getContentSnapshot(), escrow.getCreatorSignedAt(),
                escrow.getListenerSignedAt(), escrow.getBudget(), escrow.getRemaining(), items);
    }

    private SeriesRequest lockedRequest(UUID id) {
        return requests.findByIdForUpdate(id)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy yêu cầu."));
    }

    private ContractEscrow lockEscrow(UUID requestId) {
        return escrows.lockByRequestId(requestId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Yêu cầu không thuộc luồng hợp đồng giữ tiền."));
    }

    private AppUser lockedActiveUser(UUID id, String role) {
        AppUser user = users.findByIdForUpdate(id)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy tài khoản."));
        if (!Boolean.TRUE.equals(user.getIsActive()) || user.getRole() == null
                || !role.equalsIgnoreCase(user.getRole().getRoleCode()))
            throw new PodcastWorkflowException("Tài khoản không có quyền hoặc không hoạt động.");
        return user;
    }

    private AppUser activeUser(UUID id, String role) {
        AppUser user = users.findById(id)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy tài khoản."));
        if (!Boolean.TRUE.equals(user.getIsActive()) || user.getRole() == null
                || !role.equalsIgnoreCase(user.getRole().getRoleCode()))
            throw new PodcastWorkflowException("Tài khoản không có quyền hoặc không hoạt động.");
        return user;
    }

    private void requireParticipant(ContractEscrow escrow, UUID actorId) {
        if (!escrow.getRequest().getUser().getUserId().equals(actorId)
                && !escrow.getRequest().getProducerProfile().getUser().getUserId().equals(actorId))
            throw new PodcastWorkflowException("Bạn không phải bên tham gia hợp đồng.");
    }

    private String renderSnapshot(ContractEscrow escrow, List<ContractWorkflowRequests.Stage> offers) {
        try (var input = new ClassPathResource("contracts/contract-v4.md").getInputStream()) {
            String text = new String(input.readAllBytes(), StandardCharsets.UTF_8);
            SeriesRequest request = escrow.getRequest();
            Contract contract = escrow.getContract();
            AppUser listener = request.getUser();
            AppUser creator = request.getProducerProfile().getUser();
            Map<String, String> values = Map.ofEntries(
                    Map.entry("APP_NAME", "VietCast"),
                    Map.entry("CONTRACT_ID", contract.getContractId().toString()),
                    Map.entry("CREATED_AT", contract.getCreatedAt().toString()),
                    Map.entry("LISTENER_NAME", safe(listener.getDisplayName())),
                    Map.entry("LISTENER_ID", listener.getUserId().toString()),
                    Map.entry("LISTENER_EMAIL", safe(listener.getEmail())),
                    Map.entry("CREATOR_NAME", safe(creator.getDisplayName())),
                    Map.entry("CREATOR_ID", creator.getUserId().toString()),
                    Map.entry("CREATOR_EMAIL", safe(creator.getEmail())),
                    Map.entry("CREATOR_CHANNEL", safe(request.getProducerProfile().getChannelName())),
                    Map.entry("PROJECT_NAME", safe(request.getRequestedTitle())),
                    Map.entry("AUDIO/VIDEO", escrow.getProductType()),
                    Map.entry("REQUEST_DESCRIPTION", safe(request.getDescription())),
                    Map.entry("FILE_FORMAT", safe(escrow.getFileFormat())),
                    Map.entry("DURATION", safe(escrow.getDurationDescription())),
                    Map.entry("ACCEPTANCE_CRITERIA", safe(escrow.getAcceptanceCriteria())),
                    Map.entry("TOTAL_BUDGET", escrow.getBudget().toPlainString()),
                    Map.entry("CONTRACT_VERSION", Integer.toString(escrow.getContractVersion())),
                    Map.entry("LISTENER_SIGNED_AT", "Lưu riêng trong bản ghi ký"),
                    Map.entry("CREATOR_SIGNED_AT", "Lưu riêng trong bản ghi ký"));
            for (var entry : values.entrySet()) text = text.replace("[" + entry.getKey() + "]", entry.getValue());
            StringBuilder rows = new StringBuilder();
            for (int index = 0; index < offers.size(); index++) {
                var offer = offers.get(index);
                rows.append("| ").append(index + 1).append(" | ")
                        .append(safe(offer.name())).append(" | ")
                        .append(safe(offer.description())).append(" | ")
                        .append(offer.dueAt()).append(" | ")
                        .append(offer.amount().toPlainString()).append(" VND |\n");
            }
            text = text.replace("[MILESTONE_COUNT]", Integer.toString(offers.size()));
            text = text.replace("[MILESTONE_ROWS]", rows.toString().stripTrailing());
            return text;
        } catch (Exception exception) {
            throw new PodcastWorkflowException("Không đọc được mẫu hợp đồng để tạo bản ký.");
        }
    }

    private String safe(String value) {
        return value == null ? "" : value.replaceAll("\\s+", " ")
                .replace("[", "［").replace("]", "］")
                .replace("|", "｜").replace("#", "＃")
                .replace("<", "＜").replace(">", "＞")
                .replace("*", "＊").replace("_", "＿").replace("`", "｀");
    }

    private String sha256(String content) {
        try {
            byte[] bytes = MessageDigest.getInstance("SHA-256").digest(content.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(bytes);
        } catch (Exception exception) {
            throw new IllegalStateException("SHA-256 không khả dụng", exception);
        }
    }

    private WalletTransaction record(UserWallet wallet, Payment payment, String type,
            String direction, BigDecimal amount, String reference) {
        WalletTransaction transaction = new WalletTransaction();
        transaction.setUserWallet(wallet);
        transaction.setPayment(payment);
        transaction.setTransactionType(type);
        transaction.setDirection(direction);
        transaction.setAmount(amount);
        transaction.setCurrency("VND");
        transaction.setReferenceCode(reference);
        transaction.setStatus("COMPLETED");
        transaction.setBalanceAfter(wallet == null ? null : wallet.getBalance());
        transaction.setHeldBalanceAfter(wallet == null ? null : wallet.getHeldBalance());
        return transactions.save(transaction);
    }
}
