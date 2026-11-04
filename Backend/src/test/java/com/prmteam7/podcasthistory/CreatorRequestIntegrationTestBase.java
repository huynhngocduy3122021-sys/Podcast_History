package com.prmteam7.podcasthistory;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.prmteam7.podcasthistory.config.DatabaseSeeder;
import com.prmteam7.podcasthistory.dto.response.MediaUploadResponse;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.ProducerProfile;
import com.prmteam7.podcasthistory.model.Role;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.ProducerProfileRepository;
import com.prmteam7.podcasthistory.repository.RoleRepository;
import com.prmteam7.podcasthistory.service.MediaUploadService;
import java.net.URI;
import java.time.Instant;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.security.web.FilterChainProxy;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.request.MockMultipartHttpServletRequestBuilder;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.multipart.MultipartFile;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
abstract class CreatorRequestIntegrationTestBase {
  private static final String DEFAULT_TEST_DB_URL =
      "jdbc:postgresql://localhost:5432/podcast_test";
  private static final Pattern POSTGRES_JDBC_URL =
      Pattern.compile("^jdbc:postgresql://[^/]+/([^?]+)(?:\\?.*)?$");

  @Autowired protected WebApplicationContext webApplicationContext;
  @Autowired protected FilterChainProxy springSecurityFilterChain;
  protected MockMvc mockMvc;
  protected final ObjectMapper objectMapper = new ObjectMapper();
  @Autowired protected JwtEncoder jwtEncoder;
  @Autowired protected RoleRepository roleRepository;
  @Autowired protected AppUserRepository userRepository;
  @Autowired protected ProducerProfileRepository producerProfileRepository;

  @MockitoBean protected MediaUploadService mediaUploadService;
  @MockitoBean protected DatabaseSeeder databaseSeeder;

  protected AppUser listener;
  protected AppUser otherListener;
  protected AppUser creator;
  protected AppUser otherCreator;
  protected AppUser admin;
  protected ProducerProfile creatorProfile;
  protected ProducerProfile otherCreatorProfile;

  @DynamicPropertySource
  static void registerTestDatabase(DynamicPropertyRegistry registry) {
    registry.add("spring.datasource.url", CreatorRequestIntegrationTestBase::safeTestDatabaseUrl);
  }

  private static String safeTestDatabaseUrl() {
    String url = System.getenv().getOrDefault("TEST_DB_URL", DEFAULT_TEST_DB_URL);
    Matcher matcher = POSTGRES_JDBC_URL.matcher(url);
    if (!matcher.matches()) {
      throw new IllegalStateException(
          "Creator-request integration tests require TEST_DB_URL to be a PostgreSQL JDBC URL"
              + " with an explicit database name.");
    }

    String databaseName = matcher.group(1);
    if (!databaseName.toLowerCase(java.util.Locale.ROOT).contains("test")) {
      throw new IllegalStateException(
          "Refusing to initialize the test application: PostgreSQL database name must contain"
              + " 'test'.");
    }

    URI uri = URI.create(url.substring("jdbc:".length()));
    if (uri.getHost() == null || uri.getRawUserInfo() != null) {
      throw new IllegalStateException(
          "Set TEST_DB_USERNAME and TEST_DB_PASSWORD separately; credentials must not be embedded"
              + " in TEST_DB_URL.");
    }
    return url;
  }

  @BeforeEach
  void createIsolatedActors() {
    mockMvc =
        MockMvcBuilders.webAppContextSetup(webApplicationContext)
            .addFilters(springSecurityFilterChain)
            .build();
    Role listenerRole = role("LISTENER");
    Role creatorRole = role("CREATOR");
    Role adminRole = role("ADMIN");

    listener = user(listenerRole, "listener");
    otherListener = user(listenerRole, "other-listener");
    creator = user(creatorRole, "creator");
    otherCreator = user(creatorRole, "other-creator");
    admin = user(adminRole, "admin");

    creatorProfile = profile(creator, "Approved Creator");
    otherCreatorProfile = profile(otherCreator, "Other Approved Creator");

    when(mediaUploadService.uploadMilestoneMedia(
            any(MultipartFile.class), any(UUID.class), any(UUID.class)))
        .thenAnswer(
            invocation -> {
              MultipartFile file = invocation.getArgument(0);
              return new MediaUploadResponse(
                  "test/" + UUID.randomUUID(),
                  "test-bucket",
                  null,
                  file.getContentType(),
                  file.getSize());
            });
  }

  protected Role role(String code) {
    return roleRepository
        .findByRoleCode(code)
        .orElseGet(
            () -> {
              Role role = new Role();
              role.setRoleCode(code);
              role.setRoleName(code);
              return roleRepository.saveAndFlush(role);
            });
  }

  protected AppUser user(Role role, String label) {
    AppUser user = new AppUser();
    String unique = label + "-" + UUID.randomUUID();
    user.setRole(role);
    user.setUsername("test-" + UUID.randomUUID());
    user.setEmail(unique + "@example.test");
    user.setPasswordHash("test-password-hash");
    user.setDisplayName(label);
    user.setIsActive(true);
    user.setIsVerified(true);
    user.setTokenVersion(0L);
    return userRepository.saveAndFlush(user);
  }

  protected ProducerProfile profile(AppUser owner, String channelName) {
    ProducerProfile profile = new ProducerProfile();
    profile.setUser(owner);
    profile.setChannelName(channelName + " " + UUID.randomUUID());
    profile.setVerificationStatus("APPROVED");
    return producerProfileRepository.saveAndFlush(profile);
  }

  protected String token(AppUser user) {
    Instant now = Instant.now();
    JwtClaimsSet claims =
        JwtClaimsSet.builder()
            .issuer("podcast-history-backend")
            .subject(user.getUsername())
            .issuedAt(now.minusSeconds(1))
            .expiresAt(now.plusSeconds(600))
            .claim("user_id", user.getUserId().toString())
            .claim("role", user.getRole().getRoleCode())
            .claim("token_version", user.getTokenVersion())
            .claim("token_type", "access")
            .build();
    return jwtEncoder
        .encode(
            JwtEncoderParameters.from(
                JwsHeader.with(MacAlgorithm.HS256).build(), claims))
        .getTokenValue();
  }

  protected MockHttpServletRequestBuilder as(
      MockHttpServletRequestBuilder request, AppUser user) {
    return request.header("Authorization", "Bearer " + token(user));
  }

  protected MockMultipartHttpServletRequestBuilder as(
      MockMultipartHttpServletRequestBuilder request, AppUser user) {
    return request.header("Authorization", "Bearer " + token(user));
  }

  protected MvcResult postJson(String path, AppUser actor, Object body) throws Exception {
    MockHttpServletRequestBuilder request =
        post(path).contentType(MediaType.APPLICATION_JSON).content(objectMapper.writeValueAsBytes(body));
    return mockMvc.perform(as(request, actor)).andReturn();
  }

  protected MvcResult putJson(String path, AppUser actor, Object body) throws Exception {
    MockHttpServletRequestBuilder request =
        put(path).contentType(MediaType.APPLICATION_JSON).content(objectMapper.writeValueAsBytes(body));
    return mockMvc.perform(as(request, actor)).andReturn();
  }

  protected MvcResult getAs(String path, AppUser actor) throws Exception {
    return mockMvc.perform(as(get(path), actor)).andReturn();
  }

  protected MvcResult deleteAs(String path, AppUser actor) throws Exception {
    return mockMvc.perform(as(delete(path), actor)).andReturn();
  }

  protected UUID createContractRequest() throws Exception {
    MvcResult result =
        postJson(
            "/api/requests",
            listener,
            java.util.Map.of(
                "creatorProfileId", creatorProfile.getProducerProfileId(),
                "requestedTitle", "A podcast request",
                "description", "Request details",
                "requestFee", 0,
                "currency", "VND"));
    if (result.getResponse().getStatus() != 201) {
      throw new AssertionError(
          "Could not create fixture request: "
              + result.getResponse().getStatus()
              + " "
              + result.getResponse().getContentAsString());
    }
    return UUID.fromString(
        objectMapper.readTree(result.getResponse().getContentAsByteArray())
            .get("requestId")
            .asText());
  }

  protected UUID acceptRequest(UUID requestId, int milestoneCount) throws Exception {
    java.util.List<java.util.Map<String, Object>> milestones =
        java.util.stream.IntStream.rangeClosed(1, milestoneCount)
            .mapToObj(
                index ->
                    java.util.Map.<String, Object>of(
                        "name", "Milestone " + index,
                        "description", "Deliverable " + index,
                        "amount", 100.00))
            .toList();
    MvcResult result =
        postJson(
            "/api/creator/requests/" + requestId + "/accept",
            creator,
            java.util.Map.of("responseText", "Accepted", "milestones", milestones));
    if (result.getResponse().getStatus() != 200) {
      throw new AssertionError(
          "Could not accept fixture request: "
              + result.getResponse().getStatus()
              + " "
              + result.getResponse().getContentAsString());
    }
    return UUID.fromString(
        objectMapper.readTree(result.getResponse().getContentAsByteArray())
            .get("milestones")
            .get(0)
            .get("milestoneId")
            .asText());
  }

  protected MvcResult submitMilestone(UUID milestoneId, AppUser actor) throws Exception {
    MockMultipartFile file =
        new MockMultipartFile(
            "file", "submission.mp4", "video/mp4", new byte[] {0, 0, 0, 24, 102, 116, 121, 112});
    return mockMvc
        .perform(
            as(
                multipart("/api/creator/milestones/" + milestoneId + "/submissions")
                    .file(file)
                    .param("note", "Test handoff"),
                actor))
        .andReturn();
  }
}
