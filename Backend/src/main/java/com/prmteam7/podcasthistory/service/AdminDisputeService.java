package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.request.AdminRequests.ResolveDispute;
import com.prmteam7.podcasthistory.dto.response.AdminResponses.*;
import com.prmteam7.podcasthistory.enums.DisputeDecision;
import com.prmteam7.podcasthistory.enums.ListenerWinAction;
import com.prmteam7.podcasthistory.exception.*;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;
import org.springframework.data.domain.Page;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class AdminDisputeService {
  private final AdminSupportService support;
  private final ContractRepository contracts;
  private final ContractStageRepository stages;
  private final ContractDisputeRepository disputes;
  private final PaymentRepository payments;
  private final ContractEscrowRepository escrows;
  private final DisputeStaffNotifier staffNotifier;
  private final ContractEscrowService escrowService;

  public AdminDisputeService(
      AdminSupportService support,
      ContractRepository contracts,
      ContractStageRepository stages,
      ContractDisputeRepository disputes,
      PaymentRepository payments,
      ContractEscrowRepository escrows,
      DisputeStaffNotifier staffNotifier,
      ContractEscrowService escrowService) {
    this.support = support;
    this.contracts = contracts;
    this.stages = stages;
    this.disputes = disputes;
    this.payments = payments;
    this.escrows = escrows;
    this.staffNotifier = staffNotifier;
    this.escrowService = escrowService;
  }

  public Page<ContractItem> contracts(UUID actor, String status, int page, int size) {
    support.actor(actor, true);
    return contracts
        .findAll(AdminSupportService.status(status), AdminSupportService.page(page, size))
        .map(c -> contractItem(c, false));
  }

  public ContractItem contract(UUID actor, UUID id) {
    support.actor(actor, false);
    return contractItem(
        contracts
            .findById(id)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy hợp đồng.")),
        true);
  }

  public Page<DisputeItem> disputes(UUID actor, String status, int page, int size) {
    support.actor(actor, false);
    return disputes
        .findAll(AdminSupportService.status(status), AdminSupportService.page(page, size))
        .map(this::item);
  }

  public DisputeItem dispute(UUID actor, UUID id) {
    support.actor(actor, false);
    return item(requireDispute(id));
  }

  @Transactional
  public DisputeItem open(UUID actor, UUID contractId, String reason) {
    return open(actor, contractId, reason, null);
  }

  @Transactional
  public DisputeItem openForRequest(UUID actor, UUID requestId, String reason, ListenerWinAction action) {
    ContractEscrow escrow = escrows.findByRequest_SeriesRequestId(requestId)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy yêu cầu hợp đồng giữ tiền."));
    if (escrow.getContract() == null)
      throw new ResourceConflictException("CC chưa gửi đề xuất hợp đồng.");
    return open(actor, escrow.getContract().getContractId(), reason, action);
  }

  @Transactional
  public DisputeItem open(UUID actor, UUID contractId, String reason, ListenerWinAction action) {
    var user = support.user(actor);
    var contract =
        contracts
            .lockById(contractId)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy hợp đồng."));
    boolean escrow = escrows.findByContract_ContractId(contractId).isPresent();
    boolean admin = "ADMIN".equals(user.getRole().getRoleCode()) && !escrow;
    if (!admin
        && !contract.getUser().getUserId().equals(actor)
        && !contract.getProducerProfile().getUser().getUserId().equals(actor))
      throw new ResourceForbiddenException("Không phải bên tham gia hợp đồng.");
    if (disputes.existsByContract_ContractIdAndStatus(contractId, "OPEN"))
      throw new ResourceConflictException("Hợp đồng đang có tranh chấp mở.");
    if (disputes.existsByContract_ContractIdAndStatus(contractId, "AWAITING_RESPONSE"))
      throw new ResourceConflictException("Hợp đồng đang chờ bên kia xác nhận tranh chấp.");
    if (stages.findAllByContract_ContractIdOrderByStageOrderAsc(contractId).stream()
        .anyMatch(s -> "DISPUTED".equals(s.getStatus())))
      throw new ResourceConflictException("Một đợt của hợp đồng đang có tranh chấp.");
    AdminSupportService.state(
        contract.getStatus(), "PENDING", "ACTIVE", "IN_PROGRESS", "ACCEPTED", "SIGNED", "CREATED");
    if (escrow && !"IN_PROGRESS".equals(contract.getStatus()))
      throw new ResourceConflictException("Chỉ tranh chấp hợp đồng giữ tiền đang có hiệu lực.");
    boolean listenerOpened = contract.getUser().getUserId().equals(actor);
    if (escrow && listenerOpened && action == null)
      throw new ResourceConflictException("Listener cần chọn cách xử lý khi thắng tranh chấp.");
    ContractDispute d = new ContractDispute();
    d.setContract(contract);
    d.setOpenedBy(user);
    d.setReason(reason);
    d.setPreviousContractStatus(contract.getStatus());
    d.setStatus(escrow ? "AWAITING_RESPONSE" : "OPEN");
    if (escrow && listenerOpened) d.setListenerWinAction(action);
    contract.setStatus("DISPUTED");
    d = disputes.save(d);
    if (escrow) {
      AppUser opponent = listenerOpened ? contract.getProducerProfile().getUser() : contract.getUser();
      staffNotifier.notifyCounterparty(opponent, "hợp đồng", d.getDisputeId());
    } else staffNotifier.notifyOpen("hợp đồng", d.getDisputeId());
    support.audit(user, "OPEN_DISPUTE", "CONTRACT", contractId, reason);
    if (!escrow) {
      support.notify(contract.getUser(), "CONTRACT_DISPUTE", "Tranh chấp hợp đồng", reason);
      support.notify(contract.getProducerProfile().getUser(), "CONTRACT_DISPUTE", "Tranh chấp hợp đồng", reason);
    }
    return item(d);
  }

  @Transactional
  public DisputeItem confirm(UUID actor, UUID id, ListenerWinAction action) {
    AppUser user = support.user(actor);
    ContractDispute snapshot = requireDispute(id);
    Contract contract = contracts.lockById(snapshot.getContract().getContractId()).orElseThrow();
    ContractDispute dispute = disputes.lockById(id).orElseThrow();
    if (!"AWAITING_RESPONSE".equals(dispute.getStatus()))
      throw new ResourceConflictException("Tranh chấp không còn chờ xác nhận.");
    if (!contract.getUser().getUserId().equals(actor)
        && !contract.getProducerProfile().getUser().getUserId().equals(actor))
      throw new ResourceForbiddenException("Không phải bên tham gia hợp đồng.");
    if (dispute.getOpenedBy().getUserId().equals(actor))
      throw new ResourceForbiddenException("Người mở không thể tự xác nhận tranh chấp.");
    if (!dispute.getCreatedAt().plus(3, ChronoUnit.DAYS).isAfter(Instant.now()))
      throw new ResourceConflictException("Đã hết hạn 3 ngày xác nhận tranh chấp.");
    if (contract.getUser().getUserId().equals(actor)) {
      if (action == null) throw new ResourceConflictException("Listener cần chọn cách xử lý khi thắng.");
      dispute.setListenerWinAction(action);
    }
    dispute.setOpponentConfirmedAt(Instant.now());
    dispute.setStatus("OPEN");
    staffNotifier.notifyOpen("hợp đồng", id);
    support.audit(user, "CONFIRM_DISPUTE", "CONTRACT_DISPUTE", id, "Đã xác nhận tranh chấp");
    support.notify(dispute.getOpenedBy(), "DISPUTE_CONFIRMED", "Tranh chấp đã được xác nhận",
        "Hồ sơ đã chuyển Staff: " + id);
    return item(disputes.save(dispute));
  }

  public Page<DisputeItem> mine(UUID actor, int page, int size) {
    support.user(actor);
    return disputes
        .findAll(
            (r, q, c) ->
                c.or(
                    c.equal(r.get("contract").get("user").get("userId"), actor),
                    c.equal(
                        r.get("contract").get("producerProfile").get("user").get("userId"), actor)),
            AdminSupportService.page(page, size))
        .map(this::item);
  }

  @Transactional
  public DisputeItem resolve(UUID actor, UUID id, ResolveDispute body) {
    var admin = support.actor(actor, false);
    var snapshot = requireDispute(id);
    var contract = contracts.lockById(snapshot.getContract().getContractId()).orElseThrow();
    var d = disputes.lockById(id).orElseThrow();
    AdminSupportService.state(d.getStatus(), "OPEN");
    AdminSupportService.state(contract.getStatus(), "DISPUTED");
    if (d.getOpponentConfirmedAt() != null) {
      if (body.decision() != DisputeDecision.LISTENER_WINS
          && body.decision() != DisputeDecision.CREATOR_WINS)
        throw new ResourceConflictException("Chọn bên thắng cho tranh chấp đã xác nhận.");
      finishConfirmed(admin, d, contract, body.decision(), body.note());
      return item(disputes.save(d));
    }
    if (body.decision() == DisputeDecision.LISTENER_WINS
        || body.decision() == DisputeDecision.CREATOR_WINS)
      throw new ResourceConflictException("Quyết định thắng/thua chỉ dùng cho tranh chấp đã xác nhận.");
    var contractStages =
        stages.findAllByContract_ContractIdOrderByStageOrderAsc(contract.getContractId());
    if (body.decision() == DisputeDecision.CANCEL_CONTRACT) {
      if (escrows.findByContract_ContractId(contract.getContractId()).isPresent())
        throw new ResourceConflictException("Hợp đồng giữ tiền phải dùng luồng chấm dứt và hoàn escrow.");
      if (payments.countUnrefundedContractPayments(contract.getContractId()) > 0)
        throw new ResourceConflictException(
            "Cần đối soát/hoàn tiền các mốc đã thanh toán trước khi hủy hợp đồng.");
      contract.setStatus("CANCELLED");
      contractStages.forEach(s -> s.setStatus("CANCELLED"));
    } else if (body.decision() == DisputeDecision.COMPLETE_CONTRACT) {
      if (contractStages.isEmpty()
          || contractStages.stream()
              .anyMatch(
                  s ->
                      !List.of("APPROVED", "COMPLETED")
                          .contains(s.getStatus().toUpperCase(Locale.ROOT))))
        throw new ResourceConflictException(
            "Tất cả mốc phải được duyệt trước khi kết thúc hợp đồng.");
      contract.setStatus("COMPLETED");
    } else contract.setStatus(d.getPreviousContractStatus());
    d.setStatus("RESOLVED");
    d.setDecision(body.decision().name());
    d.setReviewer(admin);
    d.setNote(body.note());
    d.setResolvedAt(Instant.now());
    support.audit(admin, "RESOLVE_DISPUTE", "CONTRACT_DISPUTE", id, body.note());
    support.notify(
        contract.getUser(),
        "DISPUTE_RESULT",
        "Kết quả tranh chấp",
        body.decision() + ": " + body.note());
    support.notify(
        contract.getProducerProfile().getUser(),
        "DISPUTE_RESULT",
        "Kết quả tranh chấp",
        body.decision() + ": " + body.note());
    return item(disputes.save(d));
  }

  @Transactional
  public DisputeItem resolveTimeout(UUID id) {
    ContractDispute snapshot = requireDispute(id);
    Contract contract = contracts.lockById(snapshot.getContract().getContractId()).orElseThrow();
    ContractDispute dispute = disputes.lockById(id).orElseThrow();
    if (!"AWAITING_RESPONSE".equals(dispute.getStatus())
        || dispute.getCreatedAt().plus(3, ChronoUnit.DAYS).isAfter(Instant.now()))
      return item(dispute);
    AdminSupportService.state(contract.getStatus(), "DISPUTED");
    DisputeDecision winner = contract.getUser().getUserId().equals(dispute.getOpenedBy().getUserId())
        ? DisputeDecision.LISTENER_WINS : DisputeDecision.CREATOR_WINS;
    finishConfirmed(null, dispute, contract, winner, "Bên còn lại không xác nhận trong 3 ngày.");
    return item(disputes.save(dispute));
  }

  private void finishConfirmed(AppUser reviewer, ContractDispute dispute, Contract contract,
      DisputeDecision winner, String note) {
    if (winner == DisputeDecision.LISTENER_WINS) {
      escrowService.resolveListenerWin(contract.getContractId(), dispute.getListenerWinAction(), null);
    } else {
      contract.setStatus(dispute.getPreviousContractStatus());
      contracts.save(contract);
    }
    dispute.setStatus("RESOLVED");
    dispute.setDecision(winner.name());
    dispute.setReviewer(reviewer);
    dispute.setNote(note);
    dispute.setResolvedAt(Instant.now());
    support.notify(contract.getUser(), "DISPUTE_RESULT", "Kết quả tranh chấp", winner + ": " + note);
    support.notify(contract.getProducerProfile().getUser(), "DISPUTE_RESULT", "Kết quả tranh chấp",
        winner + ": " + note);
  }

  private ContractDispute requireDispute(UUID id) {
    return disputes
        .findById(id)
        .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tranh chấp."));
  }

  private ContractItem contractItem(Contract c, boolean detail) {
    return new ContractItem(
        c.getContractId(),
        c.getUser().getUserId(),
        c.getProducerProfile().getProducerProfileId(),
        c.getStatus(),
        c.getCreatedAt(),
        detail
            ? stages.findAllByContract_ContractIdOrderByStageOrderAsc(c.getContractId()).stream()
                .map(
                    s ->
                        new StageItem(
                            s.getContractStageId(),
                            s.getStageName(),
                            s.getStageOrder(),
                            s.getStatus()))
                .toList()
            : List.of());
  }

  private DisputeItem item(ContractDispute d) {
    return new DisputeItem(
        d.getDisputeId(),
        d.getContract().getContractId(),
        d.getOpenedBy().getUserId(),
        d.getReason(),
        d.getPreviousContractStatus(),
        d.getStatus(),
        d.getDecision(),
        d.getNote(),
        d.getReviewer() == null ? null : d.getReviewer().getUserId(),
        d.getCreatedAt(),
        d.getResolvedAt(),
        d.getCreatedAt() == null ? null : d.getCreatedAt().plus(3, ChronoUnit.DAYS),
        d.getOpponentConfirmedAt(),
        d.getListenerWinAction() == null ? null : d.getListenerWinAction().name());
  }
}
