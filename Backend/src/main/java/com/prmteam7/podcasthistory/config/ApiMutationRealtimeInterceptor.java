package com.prmteam7.podcasthistory.config;

import com.prmteam7.podcasthistory.service.RealtimeEventPublisher;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.time.Instant;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.HandlerMapping;

/** Signals a successful API write to the caller after the controller and service have completed. */
@Component
public class ApiMutationRealtimeInterceptor implements HandlerInterceptor {
    private static final Logger log = LoggerFactory.getLogger(ApiMutationRealtimeInterceptor.class);
    private static final Set<String> WRITES = Set.of("POST", "PUT", "PATCH", "DELETE");
    private final RealtimeEventPublisher realtime;

    public ApiMutationRealtimeInterceptor(RealtimeEventPublisher realtime) {
        this.realtime = realtime;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response,
            Object handler, Exception error) {
        if (error != null || !WRITES.contains(request.getMethod())
                || response.getStatus() < 200 || response.getStatus() >= 300) return;
        Object route = request.getAttribute(HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE);
        if (!(route instanceof String pattern) || !pattern.startsWith("/api/")) return;
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (!(authentication instanceof JwtAuthenticationToken jwt) || !authentication.isAuthenticated()) return;
        String claim = jwt.getToken().getClaimAsString("user_id");
        if (claim == null) return;
        try {
            realtime.publishApiChange(UUID.fromString(claim), "API_CHANGED", Map.of(
                    "method", request.getMethod(),
                    "route", pattern,
                    "occurredAt", Instant.now().toString()));
        } catch (IllegalArgumentException ex) {
            log.warn("Skipping API change event because JWT user_id is invalid");
        } catch (RuntimeException ex) {
            log.warn("API change event could not be sent for {}", pattern, ex);
        }
    }
}
