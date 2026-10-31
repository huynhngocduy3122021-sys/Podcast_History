package com.prmteam7.podcasthistory.config;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.prmteam7.podcasthistory.service.RealtimeEventPublisher;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.servlet.HandlerMapping;

class ApiMutationRealtimeInterceptorTest {
    private final RealtimeEventPublisher realtime = mock(RealtimeEventPublisher.class);
    private final ApiMutationRealtimeInterceptor interceptor = new ApiMutationRealtimeInterceptor(realtime);
    private final HttpServletRequest request = mock(HttpServletRequest.class);
    private final HttpServletResponse response = mock(HttpServletResponse.class);

    @AfterEach
    void clearSecurity() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void successfulWriteSendsOnlyRouteTemplateToAuthenticatedCaller() {
        UUID userId = UUID.randomUUID();
        authenticate(userId);
        assertTrue(SecurityContextHolder.getContext().getAuthentication().isAuthenticated());
        when(request.getMethod()).thenReturn("POST");
        when(response.getStatus()).thenReturn(201);
        when(request.getAttribute(HandlerMapping.BEST_MATCHING_PATTERN_ATTRIBUTE))
                .thenReturn("/api/requests/{requestId}/proposal");

        interceptor.afterCompletion(request, response, new Object(), null);

        verify(realtime).publishApiChange(eq(userId), eq("API_CHANGED"),
                org.mockito.ArgumentMatchers.argThat(data -> {
                    var values = (java.util.Map<?, ?>) data;
                    return "POST".equals(values.get("method"))
                            && "/api/requests/{requestId}/proposal".equals(values.get("route"))
                            && !values.containsKey("requestId");
                }));
    }

    @Test
    void readOrFailedWriteDoesNotEmitChange() {
        authenticate(UUID.randomUUID());
        when(request.getMethod()).thenReturn("GET", "PATCH");
        when(response.getStatus()).thenReturn(200, 409);

        interceptor.afterCompletion(request, response, new Object(), null);
        interceptor.afterCompletion(request, response, new Object(), null);

        verify(realtime, never()).publishApiChange(any(), any(), any());
    }

    private void authenticate(UUID userId) {
        Jwt jwt = Jwt.withTokenValue("test").header("alg", "none")
                .claim("user_id", userId.toString()).build();
        SecurityContextHolder.getContext().setAuthentication(new JwtAuthenticationToken(jwt,
                java.util.List.of(new SimpleGrantedAuthority("ROLE_LISTENER"))));
    }
}
