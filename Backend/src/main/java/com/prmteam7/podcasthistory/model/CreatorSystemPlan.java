package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "\"Creator_system_plan\"", uniqueConstraints =
    @UniqueConstraint(name = "uk_creator_system_plan_code", columnNames = "code"))
public class CreatorSystemPlan extends UpdatedEntity {
  @Id
  @Column(name = "plan_id", nullable = false, updatable = false)
  private UUID planId;

  @Column(name = "code", nullable = false, length = 60, updatable = false)
  private String code;

  @Column(name = "name", nullable = false, length = 150)
  private String name;

  @Column(name = "description", columnDefinition = "text")
  private String description;

  @Column(name = "price", nullable = false, precision = 12, scale = 2)
  private BigDecimal price;

  @Column(name = "currency", nullable = false, length = 3)
  private String currency;

  @Column(name = "duration_days")
  private Integer durationDays;

  @Column(name = "status", nullable = false, length = 30)
  private String status;

  @ElementCollection(fetch = FetchType.EAGER)
  @CollectionTable(name = "\"Creator_system_plan_benefit\"", joinColumns = @JoinColumn(name = "plan_id"))
  @OrderColumn(name = "sort_order")
  private List<CreatorSystemBenefit> benefits = new ArrayList<>();

  @PrePersist
  private void assignId() { if (planId == null) planId = UUID.randomUUID(); }

  public UUID getPlanId() { return planId; }
  public String getCode() { return code; }
  public void setCode(String code) { this.code = code; }
  public String getName() { return name; }
  public void setName(String name) { this.name = name; }
  public String getDescription() { return description; }
  public void setDescription(String description) { this.description = description; }
  public BigDecimal getPrice() { return price; }
  public void setPrice(BigDecimal price) { this.price = price; }
  public String getCurrency() { return currency; }
  public void setCurrency(String currency) { this.currency = currency; }
  public Integer getDurationDays() { return durationDays; }
  public void setDurationDays(Integer durationDays) { this.durationDays = durationDays; }
  public String getStatus() { return status; }
  public void setStatus(String status) { this.status = status; }
  public List<CreatorSystemBenefit> getBenefits() { return benefits; }
  public void setBenefits(List<CreatorSystemBenefit> benefits) { this.benefits = benefits; }
}
