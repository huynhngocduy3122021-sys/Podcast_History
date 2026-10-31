package com.prmteam7.podcasthistory.service;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.prmteam7.podcasthistory.dto.request.AcceptSeriesRequest;
import com.prmteam7.podcasthistory.dto.request.CreateSeriesRequest;
import com.prmteam7.podcasthistory.dto.request.MilestoneOffer;
import com.prmteam7.podcasthistory.dto.request.ResolveDisputeRequest;
import com.prmteam7.podcasthistory.dto.request.RejectSeriesRequest;
import com.prmteam7.podcasthistory.dto.request.SendSeriesRequestMessage;
import com.prmteam7.podcasthistory.dto.response.DisputeResponse;
import com.prmteam7.podcasthistory.dto.response.ContractWorkflowResponses;
import com.prmteam7.podcasthistory.dto.response.CreatorRequestListItem;
import com.prmteam7.podcasthistory.dto.response.MilestoneApprovalResponse;
import com.prmteam7.podcasthistory.dto.response.MilestoneResponse;
import com.prmteam7.podcasthistory.dto.response.MilestoneSubmissionResponse;
import com.prmteam7.podcasthistory.dto.response.MediaUploadResponse;
import com.prmteam7.podcasthistory.dto.response.SeriesRequestDecisionResponse;
import com.prmteam7.podcasthistory.dto.response.SeriesRequestMessageResponse;
import com.prmteam7.podcasthistory.dto.response.SeriesRequestResponse;
import com.prmteam7.podcasthistory.enums.ContractStageStatus;
import com.prmteam7.podcasthistory.enums.MilestoneDisputeDecision;
import com.prmteam7.podcasthistory.enums.ListenerWinAction;
import com.prmteam7.podcasthistory.enums.DisputeStatus;
import com.prmteam7.podcasthistory.enums.RequestStatus;
import com.prmteam7.podcasthistory.enums.UserRole;
import com.prmteam7.podcasthistory.exception.PodcastWorkflowException;
import com.prmteam7.podcasthistory.exception.PodcastWorkflowNotFoundException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.Contract;
import com.prmteam7.podcasthistory.model.ContractEscrow;
import com.prmteam7.podcasthistory.model.ContractStage;
import com.prmteam7.podcasthistory.model.MilestoneDispute;
import com.prmteam7.podcasthistory.model.MilestoneRevision;
import com.prmteam7.podcasthistory.model.MilestoneSubmission;
import com.prmteam7.podcasthistory.model.Payment;
import com.prmteam7.podcasthistory.model.ProducerProfile;
import com.prmteam7.podcasthistory.model.RequestResponse;
import com.prmteam7.podcasthistory.model.SeriesRequest;
import com.prmteam7.podcasthistory.model.SeriesRequestMessage;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.ContractRepository;
import com.prmteam7.podcasthistory.repository.ContractEscrowRepository;
import com.prmteam7.podcasthistory.repository.ContractStageRepository;
import com.prmteam7.podcasthistory.repository.MilestoneDisputeRepository;
import com.prmteam7.podcasthistory.repository.MilestoneRevisionRepository;
import com.prmteam7.podcasthistory.repository.MilestoneSubmissionRepository;
import com.prmteam7.podcasthistory.repository.PaymentRepository;
import com.prmteam7.podcasthistory.repository.ProducerProfileRepository;
import com.prmteam7.podcasthistory.repository.RequestResponseRepository;
import com.prmteam7.podcasthistory.repository.SeriesRequestRepository;
import com.prmteam7.podcasthistory.repository.SeriesRequestMessageRepository;

@Service
public class PodcastRequestService {

    private static final BigDecimal ZERO = BigDecimal.ZERO.setScale(2);
    private static final int MAX_LISTENER_REVISIONS_PER_STAGE = 3;

    private final AppUserRepository userRepository;
    private final ProducerProfileRepository creatorRepository;
    private final SeriesRequestRepository requestRepository;
    private final ContractEscrowRepository contractEscrowRepository;
    private final SeriesRequestMessageRepository messageRepository;
    private final RequestResponseRepository responseRepository;
    private final ContractRepository contractRepository;
    private final ContractStageRepository stageRepository;
    private final MilestoneSubmissionRepository submissionRepository;
    private final MilestoneRevisionRepository revisionRepository;
    private final MilestoneDisputeRepository disputeRepository;
    private final PaymentRepository paymentRepository;
    private final MediaUploadService mediaUploadService;
    private final ContractEscrowService escrowService;
    private final R2PlaybackUrlService playbackUrlService;
    private final DisputeStaffNotifier staffNotifier;

    public PodcastRequestService(
            AppUserRepository userRepository,
            ProducerProfileRepository creatorRepository,
            SeriesRequestRepository requestRepository,
            ContractEscrowRepository contractEscrowRepository,
            SeriesRequestMessageRepository messageRepository,
            RequestResponseRepository responseRepository,
            ContractRepository contractRepository,
            ContractStageRepository stageRepository,
            MilestoneSubmissionRepository submissionRepository,
            MilestoneRevisionRepository revisionRepository,
            MilestoneDisputeRepository disputeRepository,
            PaymentRepository paymentRepository,
            MediaUploadService mediaUploadService,
            ContractEscrowService escrowService,
            R2PlaybackUrlService playbackUrlService,
            DisputeStaffNotifier staffNotifier) {
        this.userRepository = userRepository;
        this.creatorRepository = creatorRepository;
        this.requestRepository = requestRepository;
        this.contractEscrowRepository = contractEscrowRepository;
        this.messageRepository = messageRepository;
        this.responseRepository = responseRepository;
        this.contractRepository = contractRepository;
        this.stageRepository = stageRepository;
        this.submissionRepository = submissionRepository;
        this.revisionRepository = revisionRepository;
        this.disputeRepository = disputeRepository;
        this.paymentRepository = paymentRepository;
        this.mediaUploadService = mediaUploadService;
        this.escrowService = escrowService;
        this.playbackUrlService = playbackUrlService;
        this.staffNotifier = staffNotifier;
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
    public List<SeriesRequestResponse> getListenerRequests(UUID listenerId) { // UUID là 
        requireRole(requireActiveUser(listenerId), UserRole.LISTENER);
        return requestRepository.findAllByUser_UserIdOrderByCreatedAtDesc(listenerId)
                .stream().map(this::toRequestResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<SeriesRequestMessageResponse> getRequestMessages(UUID userId, UUID requestId) {
        SeriesRequest request = requestRepository.findById(requestId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Request not found."));
        requireRequestParticipant(request, userId);
        return messageRepository.findAllBySeriesRequest_SeriesRequestIdOrderByCreatedAtAsc(requestId)
                .stream().map(this::toMessageResponse).toList();
    }

    @Transactional
    public SeriesRequestMessageResponse sendRequestMessage(
            UUID userId, UUID requestId, SendSeriesRequestMessage input) {
        SeriesRequest request = requestRepository.findById(requestId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Request not found."));
        AppUser sender = requireActiveUser(userId);
        requireRequestParticipant(request, userId);
        SeriesRequestMessage message = new SeriesRequestMessage();
        message.setSeriesRequest(request);
        message.setSender(sender);
        message.setContent(input.content().trim());
        return toMessageResponse(messageRepository.save(message));
    }

    @Transactional(readOnly = true)
    public List<SeriesRequestResponse> getCreatorInbox(UUID creatorUserId) {
        ProducerProfile creator = requireCreatorProfile(creatorUserId);
        return requestRepository.findAllByProducerProfile_User_UserIdAndStatusOrderByCreatedAtAsc(
                        creator.getUser().getUserId(), RequestStatus.PENDING.name())
                .stream().map(this::toRequestResponse).toList();
    }

    @Transactional(readOnly = true)
    public Page<CreatorRequestListItem> getCreatorRequests(UUID creatorUserId, String status, int page, int size) {
        ProducerProfile creator = requireCreatorProfile(creatorUserId);
        String normalizedStatus = status == null || status.isBlank()
                ? null : status.trim().toUpperCase(Locale.ROOT);
        if (normalizedStatus != null && !List.of("PENDING", "ACCEPTED", "REJECTED", "CANCELLED")
                .contains(normalizedStatus))
            throw new PodcastWorkflowException("Trạng thái request không hợp lệ.");
        var paging = PageRequest.of(Math.max(0, page), Math.min(100, Math.max(1, size)),
                Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("seriesRequestId")));
        Page<SeriesRequest> requests = normalizedStatus == null
                ? requestRepository.findAllByProducerProfile_User_UserId(creator.getUser().getUserId(), paging)
                : requestRepository.findAllByProducerProfile_User_UserIdAndStatus(
                        creator.getUser().getUserId(), normalizedStatus, paging);
        if (requests.isEmpty()) return requests.map(request -> toCreatorRequestListItem(request, null));
        Map<UUID, ContractEscrow> escrowsByRequest = contractEscrowRepository
                .findAllByRequest_SeriesRequestIdIn(requests.getContent().stream()
                        .map(SeriesRequest::getSeriesRequestId).toList())
                .stream().collect(Collectors.toMap(e -> e.getRequest().getSeriesRequestId(), Function.identity()));
        return requests.map(request -> toCreatorRequestListItem(request,
                escrowsByRequest.get(request.getSeriesRequestId())));
    }

    private CreatorRequestListItem toCreatorRequestListItem(SeriesRequest request, ContractEscrow escrow) {
        Contract contract = escrow == null ? null : escrow.getContract();
        return new CreatorRequestListItem(request.getSeriesRequestId(), request.getUser().getUserId(),
                request.getProducerProfile().getProducerProfileId(), request.getRequestedTitle(),
                request.getDescription(), request.getRequestFee(), request.getCurrency(), request.getStatus(),
                escrow == null ? "LEGACY" : "ESCROW", escrow == null ? null : escrow.getProductType(),
                contract == null ? null : contract.getContractId(), contract == null ? null : contract.getStatus(),
                request.getCreatedAt(), request.getRespondedAt(), displayName(request.getUser()),
                request.getUser().getAvatarUrl(), request.getProducerProfile().getChannelName(),
                request.getProducerProfile().getAvatarUrl());
    }

    @Transactional
    public SeriesRequestDecisionResponse acceptRequest(
            UUID creatorUserId, UUID requestId, AcceptSeriesRequest input) {
        ProducerProfile creator = requireCreatorProfile(creatorUserId);
        SeriesRequest request = requestRepository.findByIdForUpdate(requestId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy yêu cầu podcast."));
        requireRequestOwner(request, creator);
        requirePendingRequest(request);
        if (escrowService.isEscrowRequest(requestId)) {
            throw new PodcastWorkflowException("Yêu cầu hợp đồng phải dùng API proposal và ký hợp đồng.");
        }
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
        escrowService.refundRejectedRequest(request);
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
        escrowService.requireActiveSigned(stage.getContract());
        escrowService.requirePreviousStagesApproved(stage);
        requireStageStatus(stage, ContractStageStatus.NOT_STARTED, ContractStageStatus.REVISION_REQUESTED);

        if (escrowService.isEscrowContract(stage.getContract()))
            throw new PodcastWorkflowException("Hợp đồng giữ tiền phải upload bản nháp, chờ AI duyệt rồi mới gọi API bàn giao.");

        MediaUploadResponse uploaded = mediaUploadService.uploadMilestoneMedia(file, creatorUserId, stageId);
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
        if (!isDisputeReviewer(requester)) {
            requireParticipantRole(requester);
            requireStageParticipant(stage, userId);
        }
        return submissionRepository.findAllByContractStage_ContractStageIdOrderByRevisionNumberAsc(stageId)
                .stream().map(this::toSubmissionResponse).toList();
    }

    @Transactional(readOnly = true)
    public ContractWorkflowResponses.MediaUrl getMilestoneMediaUrl(UUID userId, UUID stageId, UUID submissionId) {
        ContractStage stage = stageRepository.findById(stageId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy đợt."));
        AppUser user = requireActiveUser(userId);
        if (!isDisputeReviewer(user)) {
            requireStageParticipant(stage, userId);
        }
        MilestoneSubmission submission = submissionRepository.findById(submissionId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy bản bàn giao."));
        if (!stageId.equals(submission.getContractStage().getContractStageId()))
            throw new PodcastWorkflowNotFoundException("Bản bàn giao không thuộc đợt này.");
        var signed = playbackUrlService.create(submission.getObjectKey(), true);
        return new ContractWorkflowResponses.MediaUrl(submissionId, signed.url(), signed.expiresAt());
    }

    @Transactional
    public MilestoneApprovalResponse approveMilestone(UUID listenerId, UUID stageId) {
        AppUser listener = requireActiveUser(listenerId);
        requireRole(listener, UserRole.LISTENER);
        ContractStage stage = requireStageForUpdate(stageId);
        requireListenerParticipant(stage, listenerId);
        requireStageStatus(stage, ContractStageStatus.SUBMITTED);
        escrowService.requireActiveSigned(stage.getContract());

        if (escrowService.isEscrowContract(stage.getContract())) {
            ContractWorkflowResponses.Settlement settlement = escrowService.settle(stage);
            stage.setStatus(ContractStageStatus.APPROVED.name());
            stageRepository.save(stage);
            updateContractStatusIfAllApproved(stage.getContract());
            return new MilestoneApprovalResponse(stageId, stage.getStatus(), settlement.paymentId(),
                    settlement.status(), settlement.grossAmount(), "VND", "Đã giải ngân từ ngân sách giữ.",
                    settlement.creatorNet(), settlement.platformFee(), settlement.remainingHeld());
        }
        Payment payment = createPendingPayment(stage);
        stage.setStatus(ContractStageStatus.APPROVED.name());
        stageRepository.save(stage);
        updateContractStatusIfAllApproved(stage.getContract());
        return toApprovalResponse(stage, payment);
    }

    @Transactional
    public void autoApproveMilestone(UUID stageId) {
        ContractStage stage = requireStageForUpdate(stageId);
        if (!ContractStageStatus.SUBMITTED.name().equals(stage.getStatus())
                || !"IN_PROGRESS".equals(stage.getContract().getStatus())
                || !escrowService.autoAcceptEnabled(stage.getContract())) return;
        MilestoneSubmission latest = submissionRepository
                .findFirstByContractStage_ContractStageIdOrderBySubmittedAtDesc(stageId).orElse(null);
        if (latest == null) return;
        Instant waitingSince = latest.getSubmittedAt();
        MilestoneDispute creatorWin = disputeRepository
                .findFirstByContractStage_ContractStageIdAndDecisionOrderByResolvedAtDesc(
                        stageId, MilestoneDisputeDecision.CREATOR_WINS.name()).orElse(null);
        if (creatorWin != null && creatorWin.getResolvedAt() != null
                && creatorWin.getResolvedAt().isAfter(waitingSince))
            waitingSince = creatorWin.getResolvedAt();
        if (waitingSince.plus(3, ChronoUnit.DAYS).isAfter(Instant.now())) return;
        escrowService.settle(stage);
        stage.setStatus(ContractStageStatus.APPROVED.name());
        stageRepository.save(stage);
        updateContractStatusIfAllApproved(stage.getContract());
    }

    @Transactional
    public void requestMilestoneRevision(UUID listenerId, UUID stageId, String reason) {
        AppUser listener = requireActiveUser(listenerId);
        requireRole(listener, UserRole.LISTENER);
        ContractStage stage = requireStageForUpdate(stageId);
        requireListenerParticipant(stage, listenerId);
        requireStageStatus(stage, ContractStageStatus.SUBMITTED);
        escrowService.requireActiveSigned(stage.getContract());

        long previousRevisions = revisionRepository.countByContractStage_ContractStageIdAndRequestedBy_UserId(stageId, listenerId);
        if (previousRevisions >= MAX_LISTENER_REVISIONS_PER_STAGE) {
            throw new PodcastWorkflowException("Đợt này đã hết 3 lượt yêu cầu làm lại; hãy mở tranh chấp nếu hai bên chưa thống nhất.");
        }

        recordRevision(stage, listener, reason);
        stage.setStatus(ContractStageStatus.REVISION_REQUESTED.name());
        stageRepository.save(stage);
    }

    @Transactional
    public DisputeResponse raiseDispute(UUID userId, UUID stageId, String reason) {
        return raiseDispute(userId, stageId, reason, null);
    }

    @Transactional
    public DisputeResponse raiseDispute(UUID userId, UUID stageId, String reason, ListenerWinAction action) {
        AppUser user = requireActiveUser(userId);
        ContractStage stage = requireStageForUpdate(stageId);
        requireStageParticipant(stage, userId);
        escrowService.requireActiveSigned(stage.getContract());
        if (user.getRole() == null
                || !(UserRole.LISTENER.name().equalsIgnoreCase(user.getRole().getRoleCode())
                || UserRole.CREATOR.name().equalsIgnoreCase(user.getRole().getRoleCode()))) {
            throw new PodcastWorkflowException("Chỉ Listener hoặc Creator tham gia hợp đồng mới được mở tranh chấp.");
        }
        requireStageStatus(stage, ContractStageStatus.SUBMITTED, ContractStageStatus.REVISION_REQUESTED);
        boolean escrow = escrowService.isEscrowContract(stage.getContract());
        boolean listenerOpened = stage.getContract().getUser().getUserId().equals(userId);
        if (disputeRepository.findFirstByContractStage_ContractStageIdAndStatus(
                stageId, DisputeStatus.OPEN.name()).isPresent()) {
            throw new PodcastWorkflowException("Mốc này đang có tranh chấp cần Admin xử lý.");
        }
        if (disputeRepository.findFirstByContractStage_ContractStageIdAndStatus(
                stageId, "AWAITING_RESPONSE").isPresent())
            throw new PodcastWorkflowException("Mốc này đang chờ bên kia xác nhận tranh chấp.");

        MilestoneDispute dispute = new MilestoneDispute();
        dispute.setContractStage(stage);
        dispute.setRaisedBy(user);
        dispute.setReason(reason.trim());
        dispute.setStatus(escrow ? "AWAITING_RESPONSE" : DisputeStatus.OPEN.name());
        dispute.setPreviousStageStatus(stage.getStatus());
        if (escrow && listenerOpened) dispute.setListenerWinAction(action);
        stage.setStatus(ContractStageStatus.DISPUTED.name());
        stageRepository.save(stage);
        dispute = disputeRepository.save(dispute);
        if (escrow) {
            AppUser opponent = listenerOpened ? stage.getContract().getProducerProfile().getUser()
                    : stage.getContract().getUser();
            staffNotifier.notifyCounterparty(opponent, "đợt", dispute.getMilestoneDisputeId());
        } else staffNotifier.notifyOpen("đợt", dispute.getMilestoneDisputeId());
        return toDisputeResponse(dispute);
    }

    @Transactional
    public DisputeResponse confirmMilestoneDispute(UUID actorId, UUID stageId, UUID disputeId,
            ListenerWinAction action) {
        requireActiveUser(actorId);
        ContractStage stage = requireStageForUpdate(stageId);
        requireStageParticipant(stage, actorId);
        MilestoneDispute dispute = disputeRepository.findByIdForUpdate(disputeId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy tranh chấp đợt."));
        if (!stageId.equals(dispute.getContractStage().getContractStageId())
                || !"AWAITING_RESPONSE".equals(dispute.getStatus()))
            throw new PodcastWorkflowException("Tranh chấp không còn chờ xác nhận.");
        if (actorId.equals(dispute.getRaisedBy().getUserId()))
            throw new PodcastWorkflowException("Người mở không thể tự xác nhận tranh chấp.");
        if (!dispute.getCreatedAt().plus(3, ChronoUnit.DAYS).isAfter(Instant.now()))
            throw new PodcastWorkflowException("Đã hết hạn 3 ngày xác nhận tranh chấp.");
        if (stage.getContract().getUser().getUserId().equals(actorId)) {
            dispute.setListenerWinAction(action);
        }
        dispute.setOpponentConfirmedAt(Instant.now());
        dispute.setStatus(DisputeStatus.OPEN.name());
        staffNotifier.notifyOpen("đợt", disputeId);
        staffNotifier.notifyConfirmed(dispute.getRaisedBy(), disputeId);
        return toDisputeResponse(disputeRepository.save(dispute));
    }

    @Transactional
    public DisputeResponse withdrawMilestoneDispute(UUID actorId, UUID stageId, UUID disputeId) {
        requireActiveUser(actorId);
        ContractStage stage = requireStageForUpdate(stageId);
        requireStageParticipant(stage, actorId);
        MilestoneDispute dispute = disputeRepository.findByIdForUpdate(disputeId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy tranh chấp đợt."));
        if (!stageId.equals(dispute.getContractStage().getContractStageId()))
            throw new PodcastWorkflowNotFoundException("Tranh chấp không thuộc đợt này.");
        if (!actorId.equals(dispute.getRaisedBy().getUserId()))
            throw new PodcastWorkflowException("Chỉ người mở tranh chấp được rút đơn.");
        if ("WITHDRAWN".equals(dispute.getStatus())) return toDisputeResponse(dispute);
        if (!"AWAITING_RESPONSE".equals(dispute.getStatus())
                || !dispute.getCreatedAt().plus(3, ChronoUnit.DAYS).isAfter(Instant.now()))
            throw new PodcastWorkflowException("Chỉ được rút tranh chấp trước khi bên kia xác nhận và còn trong hạn 3 ngày.");
        requireStageStatus(stage, ContractStageStatus.DISPUTED);
        stage.setStatus(dispute.getPreviousStageStatus());
        dispute.setStatus("WITHDRAWN");
        dispute.setResolvedAt(Instant.now());
        stageRepository.save(stage);
        disputeRepository.save(dispute);
        AppUser opponent = stage.getContract().getUser().getUserId().equals(actorId)
                ? stage.getContract().getProducerProfile().getUser() : stage.getContract().getUser();
        staffNotifier.notifyWithdrawn(opponent, "đợt", disputeId);
        return toDisputeResponse(dispute);
    }

    @Transactional(readOnly = true)
    public List<DisputeResponse> getOpenDisputes(UUID adminId) {
        requireDisputeReviewer(requireActiveUser(adminId));
        return disputeRepository.findAllByStatusOrderByCreatedAtAsc(DisputeStatus.OPEN.name())
                .stream().map(this::toDisputeResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<DisputeResponse> getDisputes(UUID adminId, String status) {
        requireDisputeReviewer(requireActiveUser(adminId));
        String selected = status == null || status.isBlank() ? "OPEN" : status.trim().toUpperCase(Locale.ROOT);
        return disputeRepository.findAllByStatusOrderByCreatedAtAsc(selected)
                .stream().map(this::toDisputeResponse).toList();
    }

    @Transactional
    public DisputeResponse resolveDispute(UUID adminId, UUID disputeId, ResolveDisputeRequest input) {
        AppUser admin = requireActiveUser(adminId);
        requireDisputeReviewer(admin);
        UUID contractId = disputeRepository.findContractIdByDisputeId(disputeId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy tranh chấp."));
        contractRepository.lockById(contractId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy hợp đồng."));
        UUID stageId = disputeRepository.findById(disputeId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy tranh chấp."))
                .getContractStage().getContractStageId();
        ContractStage stage = requireStageForUpdate(stageId);
        MilestoneDispute dispute = disputeRepository.findByIdForUpdate(disputeId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy tranh chấp."));
        if (!DisputeStatus.OPEN.name().equals(dispute.getStatus())) {
            throw new PodcastWorkflowException("Tranh chấp này đã được xử lý.");
        }

        requireStageStatus(stage, ContractStageStatus.DISPUTED);
        if (dispute.getOpponentConfirmedAt() != null) {
            if (input.decision() != MilestoneDisputeDecision.LISTENER_WINS
                    && input.decision() != MilestoneDisputeDecision.CREATOR_WINS)
                throw new PodcastWorkflowException("Staff phải chọn bên thắng cho tranh chấp đã xác nhận.");
            finishConfirmedMilestoneDispute(dispute, stage, admin, input.decision(), input.note());
            return toDisputeResponse(disputeRepository.save(dispute));
        }
        if (input.decision() == MilestoneDisputeDecision.LISTENER_WINS
                || input.decision() == MilestoneDisputeDecision.CREATOR_WINS)
            throw new PodcastWorkflowException("Quyết định thắng/thua chỉ dùng cho tranh chấp đã xác nhận.");
        if (input.decision() == MilestoneDisputeDecision.APPROVE_MILESTONE) {
            if (escrowService.isEscrowContract(stage.getContract())) {
                if (dispute.getCreatedAt().plus(3, ChronoUnit.DAYS).isAfter(Instant.now())) {
                    throw new PodcastWorkflowException("Chưa hết 3 ngày ưu tiên thương lượng tranh chấp.");
                }
                escrowService.settle(stage);
            } else {
                createPendingPayment(stage);
            }
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

    @Transactional
    public DisputeResponse resolveMilestoneDisputeTimeout(UUID disputeId) {
        UUID contractId = disputeRepository.findContractIdByDisputeId(disputeId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy tranh chấp."));
        contractRepository.lockById(contractId).orElseThrow();
        UUID stageId = disputeRepository.findById(disputeId).orElseThrow()
                .getContractStage().getContractStageId();
        ContractStage stage = requireStageForUpdate(stageId);
        MilestoneDispute dispute = disputeRepository.findByIdForUpdate(disputeId).orElseThrow();
        if (!"AWAITING_RESPONSE".equals(dispute.getStatus())
                || dispute.getCreatedAt().plus(3, ChronoUnit.DAYS).isAfter(Instant.now()))
            return toDisputeResponse(dispute);
        requireStageStatus(stage, ContractStageStatus.DISPUTED);
        MilestoneDisputeDecision winner = stage.getContract().getUser().getUserId()
                .equals(dispute.getRaisedBy().getUserId())
                ? MilestoneDisputeDecision.LISTENER_WINS : MilestoneDisputeDecision.CREATOR_WINS;
        finishConfirmedMilestoneDispute(dispute, stage, null, winner,
                "Bên còn lại không xác nhận trong 3 ngày.");
        return toDisputeResponse(disputeRepository.save(dispute));
    }

    private void finishConfirmedMilestoneDispute(MilestoneDispute dispute, ContractStage stage,
            AppUser reviewer, MilestoneDisputeDecision winner, String note) {
        if (winner == MilestoneDisputeDecision.LISTENER_WINS) {
            escrowService.resolveListenerWin(stage.getContract().getContractId(),
                    ListenerWinAction.CANCEL_CONTRACT, stage.getContractStageId());
        } else {
            escrowService.resolveCreatorWin(stage.getContract().getContractId());
        }
        dispute.setReviewedBy(reviewer);
        dispute.setDecision(winner.name());
        dispute.setResolutionNote(note);
        dispute.setStatus(DisputeStatus.RESOLVED.name());
        dispute.setResolvedAt(Instant.now());
        staffNotifier.notifyResult(stage.getContract().getUser(),
                stage.getContract().getProducerProfile().getUser(),
                dispute.getMilestoneDisputeId(), winner.name());
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
                .allMatch(stage -> ContractStageStatus.APPROVED.name().equals(stage.getStatus())
                        || ContractStageStatus.SKIPPED_REFUNDED.name().equals(stage.getStatus()))) {
            contract.setStatus(escrowService.isEscrowContract(contract) ? "COMPLETED" : "AWAITING_PAYMENT");
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

    private SeriesRequestMessageResponse toMessageResponse(SeriesRequestMessage message) {
        String senderName = message.getSender().getDisplayName();
        if (senderName == null || senderName.isBlank()) senderName = message.getSender().getUsername();
        return new SeriesRequestMessageResponse(
                message.getMessageId(), message.getSender().getUserId(), senderName,
                message.getContent(), message.getCreatedAt());
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
                request.getRespondedAt(),
                displayName(request.getUser()),
                request.getUser().getAvatarUrl(),
                request.getProducerProfile().getAvatarUrl());
    }

    private String displayName(AppUser user) {
        if (user.getDisplayName() != null && !user.getDisplayName().isBlank()) return user.getDisplayName();
        if (user.getUsername() != null && !user.getUsername().isBlank()) return user.getUsername();
        return user.getEmail();
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
                paymentId,
                revisionRepository.countByContractStage_ContractStageIdAndRequestedBy_UserId(
                        stage.getContractStageId(), stage.getContract().getUser().getUserId()),
                MAX_LISTENER_REVISIONS_PER_STAGE,
                stage.getDueAt());
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
        ContractStage stage = dispute.getContractStage();
        Contract contract = stage.getContract();
        SeriesRequest request = contract.getSeriesResponse() == null
                ? null : contract.getSeriesResponse().getSeriesRequest();
        return new DisputeResponse(
                dispute.getMilestoneDisputeId(),
                stage.getContractStageId(),
                dispute.getRaisedBy().getUserId(),
                dispute.getReason(),
                dispute.getStatus(),
                dispute.getDecision(),
                dispute.getResolutionNote(),
                dispute.getReviewedBy() == null ? null : dispute.getReviewedBy().getUserId(),
                dispute.getCreatedAt(),
                dispute.getResolvedAt(),
                dispute.getCreatedAt() == null ? null : dispute.getCreatedAt().plus(3, ChronoUnit.DAYS),
                dispute.getOpponentConfirmedAt(),
                dispute.getListenerWinAction() == null ? null : dispute.getListenerWinAction().name(),
                contract.getContractId(), request == null ? null : request.getSeriesRequestId(),
                request == null ? null : request.getRequestedTitle(), stage.getStageName(),
                contract.getUser().getUserId(), displayName(contract.getUser()),
                contract.getProducerProfile().getProducerProfileId(),
                contract.getProducerProfile().getChannelName(),
                displayName(dispute.getRaisedBy()),
                dispute.getReviewedBy() == null ? null : displayName(dispute.getReviewedBy()));
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

    private boolean isDisputeReviewer(AppUser user) {
        if (user.getRole() == null) return false;
        String role = user.getRole().getRoleCode();
        return UserRole.STAFF.name().equalsIgnoreCase(role)
                || UserRole.ADMIN.name().equalsIgnoreCase(role);
    }

    private void requireDisputeReviewer(AppUser user) {
        if (!isDisputeReviewer(user))
            throw new PodcastWorkflowException("Chỉ Staff hoặc Admin được xem và xử lý tranh chấp.");
    }

    private void requireParticipantRole(AppUser user) {
        if (user.getRole() == null
                || !(UserRole.LISTENER.name().equalsIgnoreCase(user.getRole().getRoleCode())
                || UserRole.CREATOR.name().equalsIgnoreCase(user.getRole().getRoleCode()))) {
            throw new PodcastWorkflowException("Chỉ Listener hoặc Creator tham gia hợp đồng mới được xem dữ liệu này.");
        }
    }

    private ContractStage requireStageForUpdate(UUID stageId) {
        ContractStage snapshot = stageRepository.findById(stageId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy mốc podcast."));
        contractRepository.lockById(snapshot.getContract().getContractId())
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy hợp đồng."));
        return stageRepository.findByIdForUpdate(stageId).orElseThrow();
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
