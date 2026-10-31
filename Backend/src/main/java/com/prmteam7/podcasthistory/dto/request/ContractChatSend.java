package com.prmteam7.podcasthistory.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.UUID;

public record ContractChatSend(@NotNull UUID clientMessageId,
                               @NotBlank @Size(max = 2000) String content) {}
