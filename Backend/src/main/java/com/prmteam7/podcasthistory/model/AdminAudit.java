package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(
    name = "\"Admin_audit\"",
    indexes = {
      @Index(name = "idx_admin_audit_resource", columnList = "resource_type,resource_id"),
      @Index(name = "idx_admin_audit_created", columnList = "created_at")
    })
public class AdminAudit extends BaseEntity {
  @Id
  @Column(name = "audit_id")
  private UUID auditId;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "actor_id")
  private AppUser actor;

  @Column(nullable = false, length = 60)
  private String action;

  @Column(name = "resource_type", nullable = false, length = 40)
  private String resourceType;

  @Column(name = "resource_id", nullable = false)
  private UUID resourceId;

  @Column(columnDefinition = "text")
  private String note;

  @PrePersist
  void assignId() {
    if (auditId == null) auditId = UUID.randomUUID();
  }

  public UUID getAuditId() {
    return auditId;
  }

  public AppUser getActor() {
    return actor;
  }

  public void setActor(AppUser v) {
    actor = v;
  }

  public String getAction() {
    return action;
  }

  public void setAction(String v) {
    action = v;
  }

  public String getResourceType() {
    return resourceType;
  }

  public void setResourceType(String v) {
    resourceType = v;
  }

  public UUID getResourceId() {
    return resourceId;
  }

  public void setResourceId(UUID v) {
    resourceId = v;
  }

  public String getNote() {
    return note;
  }

  public void setNote(String v) {
    note = v;
  }
}
