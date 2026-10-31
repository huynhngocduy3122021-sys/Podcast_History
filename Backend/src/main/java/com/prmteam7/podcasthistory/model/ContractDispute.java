package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import com.prmteam7.podcasthistory.enums.ListenerWinAction;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(
    name = "\"Contract_dispute\"",
    indexes = {@Index(name = "idx_contract_dispute_status", columnList = "status,created_at")})
public class ContractDispute extends BaseEntity {
  @Id
  @Column(name = "dispute_id")
  private UUID disputeId;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "contract_id")
  private Contract contract;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "opened_by_id")
  private AppUser openedBy;

  @Column(nullable = false, columnDefinition = "text")
  private String reason;

  @Column(name = "previous_contract_status", nullable = false, length = 30)
  private String previousContractStatus;

  @Column(nullable = false, length = 30)
  private String status;

  @Column(length = 30)
  private String decision;

  @Column(columnDefinition = "text")
  private String note;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "reviewer_id")
  private AppUser reviewer;

  @Column(name = "resolved_at")
  private Instant resolvedAt;

  @Column(name = "opponent_confirmed_at")
  private Instant opponentConfirmedAt;

  @Enumerated(EnumType.STRING)
  @Column(name = "listener_win_action", length = 30)
  private ListenerWinAction listenerWinAction;

  @PrePersist
  void assignId() {
    if (disputeId == null) disputeId = UUID.randomUUID();
  }

  public UUID getDisputeId() {
    return disputeId;
  }

  public Contract getContract() {
    return contract;
  }

  public void setContract(Contract v) {
    contract = v;
  }

  public AppUser getOpenedBy() {
    return openedBy;
  }

  public void setOpenedBy(AppUser v) {
    openedBy = v;
  }

  public String getReason() {
    return reason;
  }

  public void setReason(String v) {
    reason = v;
  }

  public String getPreviousContractStatus() {
    return previousContractStatus;
  }

  public void setPreviousContractStatus(String v) {
    previousContractStatus = v;
  }

  public String getStatus() {
    return status;
  }

  public void setStatus(String v) {
    status = v;
  }

  public String getDecision() {
    return decision;
  }

  public void setDecision(String v) {
    decision = v;
  }

  public String getNote() {
    return note;
  }

  public void setNote(String v) {
    note = v;
  }

  public AppUser getReviewer() {
    return reviewer;
  }

  public void setReviewer(AppUser v) {
    reviewer = v;
  }

  public Instant getResolvedAt() {
    return resolvedAt;
  }

  public void setResolvedAt(Instant v) {
    resolvedAt = v;
  }

  public Instant getOpponentConfirmedAt() { return opponentConfirmedAt; }
  public void setOpponentConfirmedAt(Instant value) { opponentConfirmedAt = value; }
  public ListenerWinAction getListenerWinAction() { return listenerWinAction; }
  public void setListenerWinAction(ListenerWinAction value) { listenerWinAction = value; }
}
