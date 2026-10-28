package com.prmteam7.podcasthistory.config;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

/** WebSocket/STOMP transport for user-scoped realtime events. */
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

  private final JwtDecoder jwtDecoder;
  private final String configuredOrigins;

  public WebSocketConfig(
      JwtDecoder jwtDecoder,
      @Value("${APP_CORS_ALLOWED_ORIGINS:}") String configuredOrigins) {
    this.jwtDecoder = jwtDecoder;
    this.configuredOrigins = configuredOrigins;
  }

  @Override
  public void configureMessageBroker(MessageBrokerRegistry registry) {
    registry.enableSimpleBroker("/topic", "/queue");
    registry.setApplicationDestinationPrefixes("/app");
    registry.setUserDestinationPrefix("/user");
  }

  @Override
  public void registerStompEndpoints(StompEndpointRegistry registry) {
    registry.addEndpoint("/ws").setAllowedOriginPatterns(allowedOriginPatterns());
  }

  @Override
  public void configureClientInboundChannel(ChannelRegistration registration) {
    registration.interceptors(new JwtStompChannelInterceptor(jwtDecoder));
  }

  private String[] allowedOriginPatterns() {
    if (configuredOrigins != null && !configuredOrigins.isBlank()) {
      return java.util.Arrays.stream(configuredOrigins.split(","))
          .map(String::trim)
          .filter(origin -> !origin.isBlank())
          .toArray(String[]::new);
    }
    return new String[] {
      "http://localhost:[*]",
      "http://127.0.0.1:[*]",
      "https://localhost:[*]",
      "https://127.0.0.1:[*]",
      "http://10.*:[*]",
      "https://10.*:[*]",
      "http://192.168.*:[*]",
      "https://192.168.*:[*]",
      "http://172.*:[*]",
      "https://172.*:[*]"
    };
  }

  private static final class JwtStompChannelInterceptor implements ChannelInterceptor {
    private final JwtDecoder jwtDecoder;

    private JwtStompChannelInterceptor(JwtDecoder jwtDecoder) {
      this.jwtDecoder = jwtDecoder;
    }

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
      StompHeaderAccessor accessor =
          MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
      if (accessor == null || accessor.getCommand() != StompCommand.CONNECT) {
        return message;
      }

      String authorization = accessor.getFirstNativeHeader("Authorization");
      if (authorization == null || !authorization.regionMatches(true, 0, "Bearer ", 0, 7)) {
        throw new IllegalArgumentException("WebSocket CONNECT yêu cầu Bearer token.");
      }

      String token = authorization.substring(7).trim();
      if (token.isBlank()) {
        throw new IllegalArgumentException("WebSocket CONNECT yêu cầu Bearer token.");
      }

      try {
        Jwt jwt = jwtDecoder.decode(token);
        String userId = jwt.getClaimAsString("user_id");
        if (userId == null || userId.isBlank()) {
          throw new IllegalArgumentException("JWT không có user_id.");
        }
        accessor.setUser(new UsernamePasswordAuthenticationToken(userId, null, authorities(jwt)));
        return message;
      } catch (JwtException | IllegalArgumentException ex) {
        throw new IllegalArgumentException("WebSocket token không hợp lệ.", ex);
      }
    }

    private static Collection<GrantedAuthority> authorities(Jwt jwt) {
      List<GrantedAuthority> authorities = new ArrayList<>();
      String role = jwt.getClaimAsString("role");
      if (role != null && !role.isBlank()) {
        authorities.add(new SimpleGrantedAuthority("ROLE_" + role));
      }
      return authorities;
    }
  }
}
