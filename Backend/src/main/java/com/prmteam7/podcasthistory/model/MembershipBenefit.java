package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "membership_benefit", indexes = {
        @Index(name = "idx_membership_benefit_membership_plan_id", columnList = "membership_plan_id")
    })
public class MembershipBenefit extends BaseEntity {
    @Id
    @Column(name = "membership_benefit_id", nullable = false, updatable = false)
    private UUID membershipBenefitId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "membership_plan_id", nullable = false)
    private MembershipPlan membershipPlan;

    @Column(name = "title", nullable = false, length = 180)
    private String title;

    @Column(name = "description", nullable = true, columnDefinition = "text")
    private String description;

    @Column(name = "sort_order", nullable = false)
    private Integer sortOrder;

    public MembershipBenefit() {
    }

    @PrePersist
    private void assignId() {
        if (membershipBenefitId == null) {
            membershipBenefitId = UUID.randomUUID();
        }
    }

    public UUID getMembershipBenefitId() {
        return membershipBenefitId;
    }

    public void setMembershipBenefitId(UUID membershipBenefitId) {
        this.membershipBenefitId = membershipBenefitId;
    }

    public MembershipPlan getMembershipPlan() {
        return membershipPlan;
    }

    public void setMembershipPlan(MembershipPlan membershipPlan) {
        this.membershipPlan = membershipPlan;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public Integer getSortOrder() {
        return sortOrder;
    }

    public void setSortOrder(Integer sortOrder) {
        this.sortOrder = sortOrder;
    }

}
