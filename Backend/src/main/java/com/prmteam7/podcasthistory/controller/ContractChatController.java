package com.prmteam7.podcasthistory.controller;

import com.prmteam7.podcasthistory.dto.request.ContractChatSend;
import com.prmteam7.podcasthistory.dto.response.ContractChatItem;
import com.prmteam7.podcasthistory.service.ContractChatService;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/requests/{requestId}/chat/messages")
@Tag(name = "Listener and Creator contract chat")
@SecurityRequirement(name = "bearerAuth")
public class ContractChatController {
    private final ContractChatService chat;

    public ContractChatController(ContractChatService chat) { this.chat = chat; }

    @GetMapping
    public Page<ContractChatItem> history(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID requestId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return chat.history(userId(jwt), requestId, page, size);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ContractChatItem send(@AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID requestId, @Valid @RequestBody ContractChatSend input) {
        return chat.send(userId(jwt), requestId, input);
    }

    private UUID userId(Jwt jwt) { return UUID.fromString(jwt.getClaimAsString("user_id")); }
}
