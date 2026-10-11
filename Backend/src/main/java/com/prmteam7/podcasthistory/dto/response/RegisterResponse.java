package com.prmteam7.podcasthistory.dto.response;

import java.util.UUID;

public record RegisterResponse(
        UUID id,
        String username,
        String email,
        String displayName,
        String role) {
}
