package com.prmteam7.podcasthistory.service;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.prmteam7.podcasthistory.dto.request.AcceptSeriesRequest;
import com.prmteam7.podcasthistory.dto.request.CreateSeriesRequest;
import com.prmteam7.podcasthistory.dto.request.MilestoneOffer;
import com.prmteam7.podcasthistory.dto.request.ResolveDisputeRequest;
import com.prmteam7.podcasthistory.dto.request.RejectSeriesRequest;
import com.prmteam7.podcasthistory.dto.response.DisputeResponse;
import com.prmteam7.podcasthistory.dto.response.MilestoneApprovalResponse;
import com.prmteam7.podcasthistory.dto.response.MilestoneResponse;
import com.prmteam7.podcasthistory.dto.response.MilestoneSubmissionResponse;
import com.prmteam7.podcasthistory.dto.response.MediaUploadResponse;
import com.prmteam7.podcasthistory.dto.response.SeriesRequestDecisionResponse;
import com.prmteam7.podcasthistory.dto.response.SeriesRequestResponse;
import com.prmteam7.podcasthistory.enums.ContractStageStatus;
import com.prmteam7.podcasthistory.enums.DisputeDecision;
import com.prmteam7.podcasthistory.enums.DisputeStatus;
import com.prmteam7.podcasthistory.enums.RequestStatus;
import com.prmteam7.podcasthistory.enums.UserRole;
import com.prmteam7.podcasthistory.exception.PodcastWorkflowException;
import com.prmteam7.podcasthistory.exception.PodcastWorkflowNotFoundException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.Contract;
import com.prmteam7.podcasthistory.model.ContractStage;
import com.prmteam7.podcasthistory.model.MilestoneDispute;
import com.prmteam7.podcasthistory.model.MilestoneRevision;
import com.prmteam7.podcasthistory.model.MilestoneSubmission;
import com.prmteam7.podcasthistory.model.Payment;
import com.prmteam7.podcasthistory.model.ProducerProfile;
import com.prmteam7.podcasthistory.model.RequestResponse;
import com.prmteam7.podcasthistory.model.SeriesRequest;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.ContractRepository;
import com.prmteam7.podcasthistory.repository.ContractStageRepository;
import com.prmteam7.podcasthistory.repository.MilestoneDisputeRepository;
import com.prmteam7.podcasthistory.repository.MilestoneRevisionRepository;
import com.prmteam7.podcasthistory.repository.MilestoneSubmissionRepository;
import com.prmteam7.podcasthistory.repository.PaymentRepository;
import com.prmteam7.podcasthistory.repository.ProducerProfileRepository;
import com.prmteam7.podcasthistory.repository.RequestResponseRepository;
import com.prmteam7.podcasthistory.repository.SeriesRequestRepository;

@Service
public class PodcastRequestService {

    private static final BigDecimal ZERO = BigDecimal.ZERO.setScale(2);

    private final AppUserRepository userRepository;
    private final ProducerProfileRepository creatorRepository;
    private final SeriesRequestRepository requestRepository;
    private final RequestResponseRepository responseRepository;
    private final ContractRepository contractRepository;
    private final ContractStageRepository stageRepository;
    private final MilestoneSubmissionRepository submissionRepository;
    private final MilestoneRevisionRepository revisionRepository;
    private final MilestoneDisputeRepository disputeRepository;
    private final PaymentRepository paymentRepository;
    private final MediaUploadService mediaUploadService;

    public PodcastRequestService(
            AppUserRepository userRepository,
            ProducerProfileRepository creatorRepository,
            SeriesRequestRepository requestRepository,
            RequestResponseRepository responseRepository,
            ContractRepository contractRepository,
            ContractStageRepository stageRepository,
            MilestoneSubmissionRepository submissionRepository,
            MilestoneRevisionRepository revisionRepository,
            MilestoneDisputeRepository disputeRepository,
            PaymentRepository paymentRepository,
            MediaUploadService mediaUploadService) {
        this.userRepository = userRepository;
        this.creatorRepository = creatorRepository;
        this.requestRepository = requestRepository;
        this.responseRepository = responseRepository;
        this.contractRepository = contractRepository;
        this.stageRepository = stageRepository;
        this.submissionRepository = submissionRepository;
        this.revisionRepository = revisionRepository;
        this.disputeRepository = disputeRepository;
        this.paymentRepository = paymentRepository;
        this.mediaUploadService = mediaUploadService;
    }

    @Transactional
    public SeriesRequestResponse createRequest(UUID listenerId, CreateSeriesRequest input) {
        AppUser listener = requireActiveUser(listenerId);
        requireRole(listener, UserRole.LISTENER);

        ProducerProfile creator = creatorRepository.findById(input.creatorProfileId())
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy kênh Creator."));
        requireActiveUser(creator.getUser().getUserId());
        requireRole(creator.getUser(), UserRole.CREATOR);

        SeriesRequest request = new SeriesRequest();
        request.setUser(listener);
        request.setProducerProfile(creator);
        request.setRequestedTitle(input.requestedTitle().trim());
        request.setDescription(input.description().trim());
        request.setRequestFee(input.requestFee() == null ? ZERO : input.requestFee());
        request.setCurrency(normalizeCurrency(input.currency()));
        request.setStatus(RequestStatus.PENDING.name());
        return toRequestResponse(requestRepository.save(request));
    }

    @Transactional(readOnly = true)
    public List<SeriesRequestResponse> getListenerRequests(UUID listenerId) {
        requireRole(requireActiveUser(listenerId), UserRole.LISTENER);
        return requestRepository.findAllByUser_UserIdOrderByCreatedAtDesc(listenerId)
                .stream().map(this::toRequestResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<SeriesRequestResponse> getCreatorInbox(UUID creatorUserId) {
        ProducerProfile creator = requireCreatorProfile(creatorUserId);
        return requestRepository.findAllByProducerProfile_User_UserIdAndStatusOrderByCreatedAtAsc(
                        creator.getUser().getUserId(), RequestStatus.PENDING.name())
                .stream().map(this::toRequestResponse).toList();
    }

    @Transactional
    public SeriesRequestDecisionResponse acceptRequest(
            UUID creatorUserId, UUID requestId, AcceptSeriesRequest input) {
        ProducerProfile creator = requireCreatorProfile(creatorUserId);
        SeriesRequest request = requestRepository.findByIdForUpdate(requestId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy yêu cầu podcast."));
        requireRequestOwner(request, creator);
        requirePendingRequest(request);
        validateMilestoneAmounts(input.milestones());

        RequestResponse response = new RequestResponse();
        response.setSeriesRequest(request);
        response.setProducerProfile(creator);
        response.setResponseText(input.responseText().trim());
        response.setResponseStatus(RequestStatus.ACCEPTED.name());
        RequestResponse savedResponse = responseRepository.save(response);

        Contract contract = new Contract();
        contract.setUser(request.getUser());
        contract.setProducerProfile(creator);
        contract.setSeriesResponse(savedResponse);
        contract.setStatus("IN_PROGRESS");
        contract = contractRepository.save(contract);

        int order = 1;
        for (MilestoneOffer offer : input.milestones()) {
            ContractStage stage = new ContractStage();
            stage.setContract(contract);
            stage.setStageName(offer.name().trim());
            stage.setDescription(trimToNull(offer.description()));
            stage.setStageOrder(order++);
            stage.setAmount(offer.amount());
            stage.setStatus(ContractStageStatus.NOT_STARTED.name());
            stageRepository.save(stage);
        }

        request.setStatus(RequestStatus.ACCEPTED.name());
        request.setRespondedAt(Instant.now());
        requestRepository.save(request);
        List<MilestoneResponse> milestones = stageRepository
                .findAllByContract_ContractIdOrderByStageOrder(contract.getContractId())
                .stream().map(this::toMilestoneResponse).toList();
        return new SeriesRequestDecisionResponse(toRequestResponse(request), savedResponse.getResponseText(), milestones);
    }

    @Transactional
    public SeriesRequestDecisionResponse rejectRequest(
            UUID creatorUserId, UUID requestId, RejectSeriesRequest input) {
        ProducerProfile creator = requireCreatorProfile(creatorUserId);
        SeriesRequest request = requestRepository.findByIdForUpdate(requestId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy yêu cầu podcast."));
        requireRequestOwner(request, creator);
        requirePendingRequest(request);

        RequestResponse response = new RequestResponse();
        response.setSeriesRequest(request);
        response.setProducerProfile(creator);
        response.setResponseText(input.responseText().trim());
        response.setResponseStatus(RequestStatus.REJECTED.name());
        responseRepository.save(response);

        request.setStatus(RequestStatus.REJECTED.name());
        request.setRespondedAt(Instant.now());
        requestRepository.save(request);
        return new SeriesRequestDecisionResponse(toRequestResponse(request), input.responseText().trim(), List.of());
    }

    @Transactional(readOnly = true)
    public List<MilestoneResponse> getRequestMilestones(UUID userId, UUID requestId) {
        AppUser requester = requireActiveUser(userId);
        requireParticipantRole(requester);
        SeriesRequest request = requestRepository.findById(requestId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy yêu cầu podcast."));
        requireRequestParticipant(request, userId);
        Contract contract = contractRepository.findBySeriesResponse_SeriesRequest_SeriesRequestId(requestId)
                .orElseThrow(() -> new PodcastWorkflowException("Yêu cầu chưa được Creator chấp nhận."));
        return stageRepository.findAllByContract_ContractIdOrderByStageOrder(contract.getContractId())
                .stream().map(this::toMilestoneResponse).toList();
    }

    @Transactional
    public MilestoneSubmissionResponse submitMilestone(
            UUID creatorUserId, UUID stageId, MultipartFile file, String note) {
        AppUser creator = requireActiveUser(creatorUserId);
        requireRole(creator, UserRole.CREATOR);
        if (note != null && note.length() > 5000) {
            throw new PodcastWorkflowException("Ghi chú bàn giao không được vượt quá 5000 ký tự.");
        }
        ContractStage stage = requireStageForUpdate(stageId);
        requireCreatorParticipant(stage, creatorUserId);
        requireStageStatus(stage, ContractStageStatus.NOT_STARTED, ContractStageStatus.REVISION_REQUESTED);

        MediaUploadResponse uploaded = mediaUploadService.upload(file, creatorUserId);
        long previousSubmissions = submissionRepository.countByContractStage_ContractStageId(stageId);
        MilestoneSubmission submission = new MilestoneSubmission();
        submission.setContractStage(stage);
        submission.setCreator(creator);
        submission.setRevisionNumber(Math.toIntExact(previousSubmissions + 1));
        submission.setObjectKey(uploaded.objectKey());
        submission.setPublicUrl(uploaded.publicUrl());
        submission.setContentType(uploaded.contentType());
        submission.setSubmissionNote(trimToNull(note));
        MilestoneSubmission saved = submissionRepository.save(submission);

        stage.setStatus(ContractStageStatus.SUBMITTED.name());
        stageRepository.save(stage);
        return toSubmissionResponse(saved);
    }

    @Transactional(readOnly = true)
    public List<MilestoneSubmissionResponse> getMilestoneSubmissions(UUID userId, UUID stageId) {
        ContractStage stage = stageRepository.findById(stageId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy mốc podcast."));
        AppUser requester = requireActiveUser(userId);
        if (requester.getRole() == null
                || !UserRole.ADMIN.name().equalsIgnoreCase(requester.getRole().getRoleCode())) {
            requireParticipantRole(requester);
            requireStageParticipant(stage, userId);
        }
        return submissionRepository.findAllByContractStage_ContractStageIdOrderByRevisionNumberAsc(stageId)
                .stream().map(this::toSubmissionResponse).toList();
    }

    @Transactional
    public MilestoneApprovalResponse approveMilestone(UUID listenerId, UUID stageId) {
        AppUser listener = requireActiveUser(listenerId);
        requireRole(listener, UserRole.LISTENER);
        ContractStage stage = requireStageForUpdate(stageId);
        requireListenerParticipant(stage, listenerId);
        requireStageStatus(stage, ContractStageStatus.SUBMITTED);

        Payment payment = createPendingPayment(stage);
        stage.setStatus(ContractStageStatus.APPROVED.name());
        stageRepository.save(stage);
        updateContractStatusIfAllApproved(stage.getContract());
        return toApprovalResponse(stage, payment);
    }

    @Transactional
    public void requestMilestoneRevision(UUID listenerId, UUID stageId, String reason) {
        AppUser listener = requireActiveUser(listenerId);
        requireRole(listener, UserRole.LISTENER);
        ContractStage stage = requireStageForUpdate(stageId);
        requireListenerParticipant(stage, listenerId);
        requireStageStatus(stage, ContractStageStatus.SUBMITTED);

        recordRevision(stage, listener, reason);
        stage.setStatus(ContractStageStatus.REVISION_REQUESTED.name());
        stageRepository.save(stage);
    }

    @Transactional
    public DisputeResponse raiseDispute(UUID userId, UUID stageId, String reason) {
        AppUser user = requireActiveUser(userId);
        ContractStage stage = requireStageForUpdate(stageId);
        requireStageParticipant(stage, userId);
        if (user.getRole() == null
                || !(UserRole.LISTENER.name().equalsIgnoreCase(user.getRole().getRoleCode())
                || UserRole.CREATOR.name().equalsIgnoreCase(user.getRole().getRoleCode()))) {
            throw new PodcastWorkflowException("Chỉ Listener hoặc Creator tham gia hợp đồng mới được mở tranh chấp.");
        }
        requireStageStatus(stage, ContractStageStatus.SUBMITTED, ContractStageStatus.REVISION_REQUESTED);
        if (disputeRepository.findFirstByContractStage_ContractStageIdAndStatus(
                stageId, DisputeStatus.OPEN.name()).isPresent()) {
            throw new PodcastWorkflowException("Mốc này đang có tranh chấp cần Admin xử lý.");
        }

        MilestoneDispute dispute = new MilestoneDispute();
        dispute.setContractStage(stage);
        dispute.setRaisedBy(user);
        dispute.setReason(reason.trim());
        dispute.setStatus(DisputeStatus.OPEN.name());
        stage.setStatus(ContractStageStatus.DISPUTED.name());
        stageRepository.save(stage);
        return toDisputeResponse(disputeRepository.save(dispute));
    }

    @Transactional(readOnly = true)
    public List<DisputeResponse> getOpenDisputes(UUID adminId) {
        requireRole(requireActiveUser(adminId), UserRole.ADMIN);
        return disputeRepository.findAllByStatusOrderByCreatedAtAsc(DisputeStatus.OPEN.name())
                .stream().map(this::toDisputeResponse).toList();
    }

    @Transactional
    public DisputeResponse resolveDispute(UUID adminId, UUID disputeId, ResolveDisputeRequest input) {
        AppUser admin = requireActiveUser(adminId);
        requireRole(admin, UserRole.ADMIN);
        MilestoneDispute dispute = disputeRepository.findByIdForUpdate(disputeId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy tranh chấp."));
        if (!DisputeStatus.OPEN.name().equals(dispute.getStatus())) {
            throw new PodcastWorkflowException("Tranh chấp này đã được xử lý.");
        }

        ContractStage stage = requireStageForUpdate(dispute.getContractStage().getContractStageId());
        requireStageStatus(stage, ContractStageStatus.DISPUTED);
        if (input.decision() == DisputeDecision.APPROVE_MILESTONE) {
            createPendingPayment(stage);
            stage.setStatus(ContractStageStatus.APPROVED.name());
            updateContractStatusIfAllApproved(stage.getContract());
        } else {
            recordRevision(stage, admin, input.note());
            stage.setStatus(ContractStageStatus.REVISION_REQUESTED.name());
        }
        stageRepository.save(stage);

        dispute.setReviewedBy(admin);
        dispute.setDecision(input.decision().name());
        dispute.setResolutionNote(input.note().trim());
        dispute.setStatus(DisputeStatus.RESOLVED.name());
        dispute.setResolvedAt(Instant.now());
        return toDisputeResponse(disputeRepository.save(dispute));
    }

    private Payment createPendingPayment(ContractStage stage) {
        if (paymentRepository.findFirstByContractStage_ContractStageId(stage.getContractStageId()).isPresent()) {
            throw new PodcastWorkflowException("Payment cho mốc này đã được tạo trước đó.");
        }
        Payment payment = new Payment();
        payment.setUser(stage.getContract().getUser());
        payment.setContractStage(stage);
        payment.setAmount(stage.getAmount());
        payment.setCurrency(stage.getContract().getSeriesResponse().getSeriesRequest().getCurrency());
        payment.setStatus("PENDING");
        return paymentRepository.save(payment);
    }

    private void updateContractStatusIfAllApproved(Contract contract) {
        List<ContractStage> stages = stageRepository
                .findAllByContract_ContractIdOrderByStageOrder(contract.getContractId());
        if (!stages.isEmpty() && stages.stream()
                .allMatch(stage -> ContractStageStatus.APPROVED.name().equals(stage.getStatus()))) {
            contract.setStatus("AWAITING_PAYMENT");
            contractRepository.save(contract);
        }
    }

    private void recordRevision(ContractStage stage, AppUser requester, String reason) {
        long previousRevisions = revisionRepository.countByContractStage_ContractStageId(
                stage.getContractStageId());
        MilestoneRevision revision = new MilestoneRevision();
        revision.setContractStage(stage);
        revision.setRequestedBy(requester);
        revision.setRevisionNumber(Math.toIntExact(previousRevisions + 1));
        revision.setReason(reason.trim());
        revisionRepository.save(revision);
    }

    private SeriesRequestResponse toRequestResponse(SeriesRequest request) {
        return new SeriesRequestResponse(
                request.getSeriesRequestId(),
                request.getUser().getUserId(),
                request.getProducerProfile().getProducerProfileId(),
                request.getProducerProfile().getChannelName(),
                request.getRequestedTitle(),
                request.getDescription(),
                request.getRequestFee(),
                request.getCurrency(),
                request.getStatus(),
                request.getCreatedAt(),
                request.getRespondedAt());
    }

    private MilestoneResponse toMilestoneResponse(ContractStage stage) {
        UUID paymentId = paymentRepository.findFirstByContractStage_ContractStageId(stage.getContractStageId())
                .map(Payment::getPaymentId).orElse(null);
        return new MilestoneResponse(
                stage.getContractStageId(),
                stage.getStageName(),
                stage.getDescription(),
                stage.getStageOrder(),
                stage.getAmount(),
                stage.getContract().getSeriesResponse().getSeriesRequest().getCurrency(),
                stage.getStatus(),
                paymentId);
    }

    private MilestoneSubmissionResponse toSubmissionResponse(MilestoneSubmission submission) {
        return new MilestoneSubmissionResponse(
                submission.getMilestoneSubmissionId(),
                submission.getContractStage().getContractStageId(),
                submission.getRevisionNumber(),
                submission.getObjectKey(),
                submission.getPublicUrl(),
                submission.getContentType(),
                submission.getSubmissionNote(),
                submission.getSubmittedAt());
    }

    private MilestoneApprovalResponse toApprovalResponse(ContractStage stage, Payment payment) {
        return new MilestoneApprovalResponse(
                stage.getContractStageId(),
                stage.getStatus(),
                payment.getPaymentId(),
                payment.getStatus(),
                payment.getAmount(),
                payment.getCurrency(),
                "Sản phẩm đã được duyệt; Payment đang PENDING, chưa xác nhận giao dịch từ cổng thanh toán.");
    }

    private DisputeResponse toDisputeResponse(MilestoneDispute dispute) {
        return new DisputeResponse(
                dispute.getMilestoneDisputeId(),
                dispute.getContractStage().getContractStageId(),
                dispute.getRaisedBy().getUserId(),
                dispute.getReason(),
                dispute.getStatus(),
                dispute.getDecision(),
                dispute.getResolutionNote(),
                dispute.getReviewedBy() == null ? null : dispute.getReviewedBy().getUserId(),
                dispute.getCreatedAt(),
                dispute.getResolvedAt());
    }

    private ProducerProfile requireCreatorProfile(UUID userId) {
        AppUser user = requireActiveUser(userId);
        requireRole(user, UserRole.CREATOR);
        return creatorRepository.findByUser_UserId(userId)
                .orElseThrow(() -> new PodcastWorkflowException("Tài khoản Creator chưa có hồ sơ kênh."));
    }

    private AppUser requireActiveUser(UUID userId) {
        AppUser user = userRepository.findById(userId)
                .orElseThrow(() -> new PodcastWorkflowException("Không tìm thấy tài khoản."));
        if (!Boolean.TRUE.equals(user.getIsActive())) {
            throw new PodcastWorkflowException("Tài khoản hiện không hoạt động.");
        }
        return user;
    }

    private void requireRole(AppUser user, UserRole role) {
        if (user.getRole() == null || !role.name().equalsIgnoreCase(user.getRole().getRoleCode())) {
            throw new PodcastWorkflowException("Tài khoản không có quyền thực hiện thao tác này.");
        }
    }

    private void requireParticipantRole(AppUser user) {
        if (user.getRole() == null
                || !(UserRole.LISTENER.name().equalsIgnoreCase(user.getRole().getRoleCode())
                || UserRole.CREATOR.name().equalsIgnoreCase(user.getRole().getRoleCode()))) {
            throw new PodcastWorkflowException("Chỉ Listener hoặc Creator tham gia hợp đồng mới được xem dữ liệu này.");
        }
    }

    private ContractStage requireStageForUpdate(UUID stageId) {
        return stageRepository.findByIdForUpdate(stageId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy mốc podcast."));
    }

    private void requireRequestOwner(SeriesRequest request, ProducerProfile creator) {
        if (!creator.getProducerProfileId().equals(request.getProducerProfile().getProducerProfileId())) {
            throw new PodcastWorkflowException("Yêu cầu này không thuộc kênh Creator hiện tại.");
        }
    }

    private void requireRequestParticipant(SeriesRequest request, UUID userId) {
        if (!request.getUser().getUserId().equals(userId)
                && !request.getProducerProfile().getUser().getUserId().equals(userId)) {
            throw new PodcastWorkflowException("Bạn không phải thành viên của yêu cầu này.");
        }
    }

    private void requireStageParticipant(ContractStage stage, UUID userId) {
        if (!stage.getContract().getUser().getUserId().equals(userId)
                && !stage.getContract().getProducerProfile().getUser().getUserId().equals(userId)) {
            throw new PodcastWorkflowException("Bạn không phải thành viên của hợp đồng này.");
        }
    }

    private void requireListenerParticipant(ContractStage stage, UUID listenerId) {
        if (!stage.getContract().getUser().getUserId().equals(listenerId)) {
            throw new PodcastWorkflowException("Chỉ Listener đã tạo yêu cầu mới được duyệt hoặc yêu cầu chỉnh sửa.");
        }
    }

    private void requireCreatorParticipant(ContractStage stage, UUID creatorId) {
        if (!stage.getContract().getProducerProfile().getUser().getUserId().equals(creatorId)) {
            throw new PodcastWorkflowException("Mốc này không thuộc hợp đồng của Creator hiện tại.");
        }
    }

    private void requirePendingRequest(SeriesRequest request) {
        if (!RequestStatus.PENDING.name().equals(request.getStatus())) {
            throw new PodcastWorkflowException("Yêu cầu này đã được Creator xử lý.");
        }
    }

    private void requireStageStatus(ContractStage stage, ContractStageStatus... allowedStatuses) {
        for (ContractStageStatus allowedStatus : allowedStatuses) {
            if (allowedStatus.name().equals(stage.getStatus())) {
                return;
            }
        }
        throw new PodcastWorkflowException(
                "Thao tác không hợp lệ với trạng thái mốc hiện tại: " + stage.getStatus());
    }

    private void validateMilestoneAmounts(List<MilestoneOffer> milestones) {
        BigDecimal total = BigDecimal.ZERO;
        for (MilestoneOffer milestone : milestones) {
            BigDecimal amount = milestone.amount();
            if (amount.scale() > 2 || amount.precision() > 12) {
                throw new PodcastWorkflowException("Số tiền mỗi mốc tối đa 10 chữ số nguyên và 2 chữ số thập phân.");
            }
            total = total.add(amount);
        }
        if (total.precision() > 12 || total.scale() > 2) {
            throw new PodcastWorkflowException("Tổng giá trị các mốc vượt giới hạn cho phép.");
        }
    }

    private String normalizeCurrency(String currency) {
        return currency == null || currency.isBlank() ? "USD" : currency.trim().toUpperCase(Locale.ROOT);
    }

    private String trimToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
