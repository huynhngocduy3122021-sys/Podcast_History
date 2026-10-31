package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.request.AdminRequests.ResolveDispute;
import com.prmteam7.podcasthistory.dto.response.AdminResponses.*;
import com.prmteam7.podcasthistory.enums.DisputeDecision;
import com.prmteam7.podcasthistory.exception.*;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.time.Instant;
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

  public AdminDisputeService(
      AdminSupportService support,
      ContractRepository contracts,
      ContractStageRepository stages,
      ContractDisputeRepository disputes,
      PaymentRepository payments,
      ContractEscrowRepository escrows,
      DisputeStaffNotifier staffNotifier) {
    this.support = support;
    this.contracts = contracts;
    this.stages = stages;
    this.disputes = disputes;
    this.payments = payments;
    this.escrows = escrows;
    this.staffNotifier = staffNotifier;
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
    var user = support.user(actor);
    var contract =
        contracts
            .lockById(contractId)
            .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy hợp đồng."));
    boolean admin = "ADMIN".equals(user.getRole().getRoleCode());
    if (!admin
        && !contract.getUser().getUserId().equals(actor)
        && !contract.getProducerProfile().getUser().getUserId().equals(actor))
      throw new ResourceForbiddenException("Không phải bên tham gia hợp đồng.");
    if (disputes.existsByContract_ContractIdAndStatus(contractId, "OPEN"))
      throw new ResourceConflictException("Hợp đồng đang có tranh chấp mở.");
    AdminSupportService.state(
        contract.getStatus(), "PENDING", "ACTIVE", "IN_PROGRESS", "ACCEPTED", "SIGNED", "CREATED");
    ContractDispute d = new ContractDispute();
    d.setContract(contract);
    d.setOpenedBy(user);
    d.setReason(reason);
    d.setPreviousContractStatus(contract.getStatus());
    d.setStatus("OPEN");
    contract.setStatus("DISPUTED");
    d = disputes.save(d);
    staffNotifier.notifyOpen("hợp đồng", d.getDisputeId());
    support.audit(user, "OPEN_DISPUTE", "CONTRACT", contractId, reason);
    support.notify(contract.getUser(), "CONTRACT_DISPUTE", "Tranh chấp hợp đồng", reason);
    support.notify(
        contract.getProducerProfile().getUser(), "CONTRACT_DISPUTE", "Tranh chấp hợp đồng", reason);
    return item(d);
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
        d.getResolvedAt());
  }
}
