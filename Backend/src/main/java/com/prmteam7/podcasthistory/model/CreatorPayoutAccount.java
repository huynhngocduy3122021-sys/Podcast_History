package com.prmteam7.podcasthistory.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "\"Creator_payout_account\"", uniqueConstraints = {
        @UniqueConstraint(name = "uk_creator_payout_account_reference", columnNames = "account_reference")
}, indexes = {
        @Index(name = "idx_creator_payout_account_creator", columnList = "producer_profile_id")
})
@Getter
@Setter
@NoArgsConstructor
public class CreatorPayoutAccount extends BaseEntity {

    @jakarta.persistence.Id
    @Column(name = "creator_payout_account_id", nullable = false, updatable = false)
    private UUID creatorPayoutAccountId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "producer_profile_id", nullable = false)
    private ProducerProfile producerProfile;

    @Column(name = "payout_method", nullable = false, length = 40)
    private String payoutMethod;

    @Column(name = "account_reference", nullable = false, length = 255)
    private String accountReference;

    @Column(name = "account_masked", nullable = false, length = 160)
    private String accountMasked;

    @Column(name = "currency", nullable = false, length = 3, columnDefinition = "char(3)")
    private String currency;

    @Column(name = "is_verified", nullable = false)
    private Boolean verified;

    @Column(name = "is_active", nullable = false)
    private Boolean active;

    @Column(name = "verified_at")
    private Instant verifiedAt;

    @PrePersist
    private void assignId() {
        if (creatorPayoutAccountId == null) {
            creatorPayoutAccountId = UUID.randomUUID();
        }
    }
}
