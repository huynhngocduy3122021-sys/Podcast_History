package com.prmteam7.podcasthistory.dto.response;

import java.time.Instant;

public record ApiError(Instant timestamp, int status, String error, String message) {
}
