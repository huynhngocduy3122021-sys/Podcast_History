package com.prmteam7.podcasthistory;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

class SimpleCreatorRequestIntegrationTest extends CreatorRequestIntegrationTestBase {
  @Test
  void createsUpdatesListsAndCancelsRequestWithoutMembership() throws Exception {
    String path = "/api/creators/" + creatorProfile.getProducerProfileId() + "/series-requests";
    var created =
        postJson(path, listener, Map.of("requestedTitle", "New episode", "description", "Please cover a new era"));
    org.junit.jupiter.api.Assertions.assertEquals(201, created.getResponse().getStatus());
    UUID requestId =
        UUID.fromString(
            objectMapper.readTree(created.getResponse().getContentAsByteArray())
                .get("seriesRequestId")
                .asText());

    mockMvc
        .perform(as(MockMvcRequestBuilders.get("/api/me/series-requests"), listener))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$", hasSize(1)))
        .andExpect(jsonPath("$[0].status").value("PENDING"));
    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.get("/api/me/series-requests"),
                otherListener))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$", hasSize(0)));

    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.put("/api/me/series-requests/" + requestId)
                    .contentType("application/json")
                    .content(
                        objectMapper.writeValueAsBytes(
                            Map.of(
                                "requestedTitle", "Edited episode",
                                "description", "Updated details"))),
                listener))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.requestedTitle").value("Edited episode"))
        .andExpect(jsonPath("$.description").value("Updated details"));

    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.put("/api/me/series-requests/" + requestId)
                    .contentType("application/json")
                    .content(
                        objectMapper.writeValueAsBytes(
                            Map.of("requestedTitle", "Hijack", "description", "Not owner"))),
                otherListener))
        .andExpect(status().isForbidden());
    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.delete("/api/me/series-requests/" + requestId),
                otherListener))
        .andExpect(status().isForbidden());

    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.delete("/api/me/series-requests/" + requestId),
                listener))
        .andExpect(status().isNoContent());
    mockMvc
        .perform(as(MockMvcRequestBuilders.get("/api/me/series-requests"), listener))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$[0].status").value("CANCELLED"));
  }

  @Test
  void rejectsInvalidSimpleRequestAndUpdateFields() throws Exception {
    String path = "/api/creators/" + creatorProfile.getProducerProfileId() + "/series-requests";
    for (Map<String, String> body :
        java.util.List.of(
            Map.of("requestedTitle", "", "description", "Details"),
            Map.of("requestedTitle", "x".repeat(221), "description", "Details"),
            Map.of("requestedTitle", "Title", "description", ""),
            Map.of("requestedTitle", "Title", "description", "x".repeat(10001)))) {
      org.junit.jupiter.api.Assertions.assertEquals(
          400, postJson(path, listener, body).getResponse().getStatus());
    }

    var created =
        postJson(path, listener, Map.of("requestedTitle", "Valid", "description", "Valid details"));
    UUID requestId =
        UUID.fromString(
            objectMapper.readTree(created.getResponse().getContentAsByteArray())
                .get("seriesRequestId")
                .asText());
    for (Map<String, String> body :
        java.util.List.of(
            Map.of("requestedTitle", "", "description", "Details"),
            Map.of("requestedTitle", "Title", "description", "x".repeat(10001)))) {
      org.junit.jupiter.api.Assertions.assertEquals(
          400,
          putJson("/api/me/series-requests/" + requestId, listener, body)
              .getResponse()
              .getStatus());
    }
  }

  @Test
  void refusesUpdateAndCancelAfterCreatorHasResponded() throws Exception {
    String path = "/api/creators/" + creatorProfile.getProducerProfileId() + "/series-requests";
    var created =
        postJson(path, listener, Map.of("requestedTitle", "Awaiting response", "description", "Details"));
    UUID requestId =
        UUID.fromString(
            objectMapper.readTree(created.getResponse().getContentAsByteArray())
                .get("seriesRequestId")
                .asText());

    org.junit.jupiter.api.Assertions.assertEquals(200, postJson(
        "/api/creator/requests/" + requestId + "/accept",
        creator,
        Map.of(
            "responseText",
            "Accepted",
            "milestones",
            java.util.List.of(Map.of("name", "First delivery", "amount", 100))))
        .getResponse()
        .getStatus());

    org.junit.jupiter.api.Assertions.assertEquals(
        409,
        putJson(
                "/api/me/series-requests/" + requestId,
                listener,
                Map.of("requestedTitle", "Too late", "description", "Late update"))
            .getResponse()
            .getStatus());
    org.junit.jupiter.api.Assertions.assertEquals(
        409,
        deleteAs("/api/me/series-requests/" + requestId, listener)
            .getResponse()
            .getStatus());
  }

  @Test
  void simpleRequestEndpointRejectsCreatorRole() throws Exception {
    String path = "/api/creators/" + creatorProfile.getProducerProfileId() + "/series-requests";
    org.junit.jupiter.api.Assertions.assertEquals(
        403,
        postJson(
                path,
                creator,
                Map.of(
                    "requestedTitle",
                    "Creator acting as listener",
                    "description",
                    "Details"))
            .getResponse()
            .getStatus());
  }
}
