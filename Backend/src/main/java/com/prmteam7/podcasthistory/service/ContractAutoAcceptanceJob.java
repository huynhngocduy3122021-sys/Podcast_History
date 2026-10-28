package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.repository.ContractStageRepository;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class ContractAutoAcceptanceJob {
    private static final Logger log = LoggerFactory.getLogger(ContractAutoAcceptanceJob.class);
    private final ContractStageRepository stages;
    private final PodcastRequestService requests;

    public ContractAutoAcceptanceJob(ContractStageRepository stages, PodcastRequestService requests) {
        this.stages = stages;
        this.requests = requests;
    }

    @Scheduled(fixedDelay = 60_000)
    public void run() {
        for (UUID id : stages.findAllByStatus("SUBMITTED").stream()
                .map(stage -> stage.getContractStageId()).toList()) {
            try {
                requests.autoApproveMilestone(id);
            } catch (RuntimeException exception) {
                log.warn("Could not auto-approve contract milestone {}", id, exception);
            }
        }
    }
}
