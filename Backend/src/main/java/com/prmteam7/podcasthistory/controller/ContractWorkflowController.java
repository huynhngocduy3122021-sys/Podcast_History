package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.ContractWorkflowRequests;
import com.prmteam7.podcasthistory.dto.response.ContractWorkflowResponses;
import com.prmteam7.podcasthistory.dto.response.AdminResponses;
import com.prmteam7.podcasthistory.service.ContractEscrowService;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@Tag(name = "Listener and Creator escrow contracts")
@SecurityRequirement(name = "bearerAuth")
public class ContractWorkflowController {
    private final ContractEscrowService service;

    public ContractWorkflowController(ContractEscrowService service) { this.service = service; }

    @PostMapping("/api/requests/contract")
    @ResponseStatus(HttpStatus.CREATED)
    public ContractWorkflowResponses.Request create(@AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody ContractWorkflowRequests.Create input) {
        return service.create(userId(jwt), input);
    }

    @PostMapping("/api/creator/requests/{requestId}/proposal")
    public ContractWorkflowResponses.Agreement propose(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID requestId, @Valid @RequestBody ContractWorkflowRequests.Proposal input) {
        return service.propose(userId(jwt), requestId, input);
    }

    @GetMapping("/api/requests/{requestId}/contract")
    public ContractWorkflowResponses.Agreement agreement(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID requestId) {
        return service.getAgreement(userId(jwt), requestId);
    }

    @PostMapping("/api/requests/{requestId}/contract/sign")
    public ContractWorkflowResponses.Agreement sign(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID requestId, @Valid @RequestBody ContractWorkflowRequests.Sign input) {
        return service.sign(userId(jwt), requestId, input);
    }

    @PostMapping("/api/requests/{requestId}/contract/cancel")
    public ContractWorkflowResponses.Request cancel(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID requestId) {
        return service.cancel(userId(jwt), requestId);
    }

    @PostMapping("/api/requests/{requestId}/termination-requests")
    @ResponseStatus(HttpStatus.CREATED)
    public AdminResponses.DisputeItem requestTermination(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID requestId, @Valid @RequestBody ContractWorkflowRequests.Dispute input) {
        return service.requestTermination(userId(jwt), requestId, input.reason());
    }

    @GetMapping("/api/requests/{requestId}/termination-request")
    public ContractWorkflowResponses.TerminationRequestStatus terminationRequest(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID requestId) {
        return service.getTerminationRequest(userId(jwt), requestId);
    }

    @PostMapping("/api/admin/contracts/{contractId}/terminate-escrow")
    public ContractWorkflowResponses.Termination terminate(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID contractId, @Valid @RequestBody ContractWorkflowRequests.Terminate input) {
        return service.terminate(userId(jwt), contractId, input);
    }

    private UUID userId(Jwt jwt) { return UUID.fromString(jwt.getClaimAsString("user_id")); }
}
