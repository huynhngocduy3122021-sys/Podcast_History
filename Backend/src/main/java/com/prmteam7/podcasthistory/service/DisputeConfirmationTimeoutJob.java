package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.model.ContractDispute;
import com.prmteam7.podcasthistory.model.MilestoneDispute;
import com.prmteam7.podcasthistory.repository.ContractDisputeRepository;
import com.prmteam7.podcasthistory.repository.MilestoneDisputeRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class DisputeConfirmationTimeoutJob {
    private static final Logger log = LoggerFactory.getLogger(DisputeConfirmationTimeoutJob.class);
    private final ContractDisputeRepository contractDisputes;
    private final MilestoneDisputeRepository milestoneDisputes;
    private final AdminDisputeService contracts;
    private final PodcastRequestService milestones;

    public DisputeConfirmationTimeoutJob(ContractDisputeRepository contractDisputes,
            MilestoneDisputeRepository milestoneDisputes, AdminDisputeService contracts,
            PodcastRequestService milestones) {
        this.contractDisputes = contractDisputes;
        this.milestoneDisputes = milestoneDisputes;
        this.contracts = contracts;
        this.milestones = milestones;
    }

    @Scheduled(fixedDelay = 60_000)
    public void resolveExpired() {
        Instant cutoff = Instant.now().minus(3, ChronoUnit.DAYS);
        for (ContractDispute dispute : contractDisputes.findAllByStatusAndCreatedAtBefore("AWAITING_RESPONSE", cutoff)) {
            try {
                contracts.resolveTimeout(dispute.getDisputeId());
            } catch (Exception ex) {
                log.error("Could not resolve expired contract dispute {}", dispute.getDisputeId(), ex);
            }
        }
        for (MilestoneDispute dispute : milestoneDisputes.findAllByStatusAndCreatedAtBefore("AWAITING_RESPONSE", cutoff)) {
            try {
                milestones.resolveMilestoneDisputeTimeout(dispute.getMilestoneDisputeId());
            } catch (Exception ex) {
                log.error("Could not resolve expired milestone dispute {}", dispute.getMilestoneDisputeId(), ex);
            }
        }
    }
}
