package com.prmteam7.podcasthistory.dto.request;

import com.prmteam7.podcasthistory.enums.ListenerWinAction;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record OpenContractDisputeRequest(@NotBlank @Size(max = 5000) String note,
                                         ListenerWinAction listenerWinAction) {}
