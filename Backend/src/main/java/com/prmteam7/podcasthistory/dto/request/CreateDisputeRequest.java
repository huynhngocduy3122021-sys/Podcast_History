package com.prmteam7.podcasthistory.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import com.prmteam7.podcasthistory.enums.ListenerWinAction;

public record CreateDisputeRequest(@NotBlank @Size(max = 5000) String reason,
                                   ListenerWinAction listenerWinAction) {
}
