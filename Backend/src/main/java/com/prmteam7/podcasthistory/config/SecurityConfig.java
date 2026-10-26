package com.prmteam7.podcasthistory.config;

import com.nimbusds.jose.jwk.source.ImmutableSecret;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Collection;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {

  private static final Logger log = LoggerFactory.getLogger(SecurityConfig.class);

  @Bean
  SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    return http.cors(org.springframework.security.config.Customizer.withDefaults())
        .csrf(AbstractHttpConfigurer::disable)
        .sessionManagement(
            session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(
            authorize ->
                authorize
                    .requestMatchers(HttpMethod.GET, "/api/categories")
                    .permitAll()
                    .requestMatchers(HttpMethod.GET, "/api/podcast-transcripts/*")
                    .hasAnyRole("CREATOR", "LISTENER")
                    .requestMatchers(
                        "/api/health",
                        "/api/auth/login",
                        "/api/auth/register",
                        "/api/auth/refresh",
                        "/api/auth/logout",
                        "/swagger-ui.html",
                        "/swagger-ui/**",
                        "/v3/api-docs/**")
                    .permitAll()
                    .requestMatchers(HttpMethod.POST, "/api/webhooks/sepay")
                    .permitAll()
                    .requestMatchers(
                        "/api/admin/dashboard",
                        "/api/admin/podcasts", "/api/admin/podcasts/**",
                        "/api/admin/reports", "/api/admin/reports/**",
                        "/api/admin/podcast-appeals", "/api/admin/podcast-appeals/**")
                    .hasAnyRole("ADMIN", "STAFF")
                    .requestMatchers("/api/admin/**")
                    .hasRole("ADMIN")
                    .requestMatchers("/api/creator/**")
                    .hasRole("CREATOR")
                    .requestMatchers("/api/livestreams/**")
                    .hasRole("LISTENER")
                    .requestMatchers("/api/listener/**")
                    .hasRole("LISTENER")
                    .requestMatchers("/api/creator-applications/**")
                    .authenticated()
                    .requestMatchers("/api/auth/me")
                    .authenticated()
                    .anyRequest()
                    .authenticated())
        .oauth2ResourceServer(
            resourceServer ->
                resourceServer.jwt(
                    jwt -> jwt.jwtAuthenticationConverter(jwtAuthenticationConverter())))
        .build();
  }

  private JwtAuthenticationConverter jwtAuthenticationConverter() {
    JwtGrantedAuthoritiesConverter scopeConverter = new JwtGrantedAuthoritiesConverter();
    JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
    converter.setJwtGrantedAuthoritiesConverter(
        jwt -> {
          Collection<GrantedAuthority> authorities = new ArrayList<>(scopeConverter.convert(jwt));
          String role = jwt.getClaimAsString("role");
          if (role != null && !role.isBlank()) {
            authorities.add(new SimpleGrantedAuthority("ROLE_" + role));
          }
          return authorities;
        });
    return converter;
  }

  @Bean
  SecretKey jwtSigningKey(@Value("${JWT_SECRET:}") String configuredSecret) {
    if (configuredSecret == null || configuredSecret.isBlank()) {
      byte[] generatedSecret = new byte[32];
      new SecureRandom().nextBytes(generatedSecret);
      log.warn(
          "JWT_SECRET is unset. Using a temporary key for this local run; tokens will expire on"
              + " restart.");
      return new SecretKeySpec(generatedSecret, "HmacSHA256");
    }

    byte[] secretBytes = configuredSecret.getBytes(StandardCharsets.UTF_8);
    if (secretBytes.length < 32) {
      throw new IllegalStateException("JWT_SECRET must contain at least 32 UTF-8 bytes for HS256.");
    }
    return new SecretKeySpec(secretBytes, "HmacSHA256");
  }

  @Bean
  JwtEncoder jwtEncoder(SecretKey jwtSigningKey) {
    return new NimbusJwtEncoder(new ImmutableSecret<>(jwtSigningKey));
  }

  @Bean
  JwtDecoder jwtDecoder(SecretKey jwtSigningKey, AccountJwtValidator accounts) {
    NimbusJwtDecoder decoder =
        NimbusJwtDecoder.withSecretKey(jwtSigningKey).macAlgorithm(MacAlgorithm.HS256).build();
    decoder.setJwtValidator(
        new org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator<>(
            org.springframework.security.oauth2.jwt.JwtValidators.createDefaultWithIssuer(
                "podcast-history-backend"),
            accounts));
    return decoder;
  }

  @Bean
  PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder();
  }

  @Bean
  org.springframework.web.cors.CorsConfigurationSource corsConfigurationSource(
      @Value("${APP_CORS_ALLOWED_ORIGINS:}") String origins) {
    var config = new org.springframework.web.cors.CorsConfiguration();
    var allowedOrigins = origins.isBlank() ? defaultCorsOrigins()
        : java.util.Arrays.stream(origins.split(","))
            .map(String::trim)
            .filter(x -> !x.isBlank())
            .toList();
    config.setAllowedOriginPatterns(allowedOrigins);
    config.setAllowedMethods(java.util.List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
    config.setAllowedHeaders(
        java.util.List.of("Authorization", "Content-Type", "Accept", "ngrok-skip-browser-warning"));
    config.setAllowCredentials(false);
    config.setMaxAge(3600L);
    var source = new org.springframework.web.cors.UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/api/**", config);
    return source;
  }

  private static java.util.List<String> defaultCorsOrigins() {
    var origins = new java.util.ArrayList<>(java.util.List.of(
        "http://localhost:[*]", "http://127.0.0.1:[*]",
        "https://localhost:[*]", "https://127.0.0.1:[*]",
        "http://10.*:[*]", "http://192.168.*:[*]",
        "https://10.*:[*]", "https://192.168.*:[*]"));
    for (int subnet = 16; subnet <= 31; subnet++) {
      origins.add("http://172." + subnet + ".*:[*]");
      origins.add("https://172." + subnet + ".*:[*]");
    }
    return origins;
  }
}
