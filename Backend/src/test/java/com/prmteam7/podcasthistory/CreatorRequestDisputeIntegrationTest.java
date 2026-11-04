package com.prmteam7.podcasthistory;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.prmteam7.podcasthistory.model.Contract;
import com.prmteam7.podcasthistory.repository.ContractRepository;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

class CreatorRequestDisputeIntegrationTest extends CreatorRequestIntegrationTestBase {
  @Autowired private ContractRepository contractRepository;

  @Test
  void enforcesMilestoneDisputeOwnershipValidationAndNoDuplicateOpenDispute() throws Exception {
    UUID requestId = createContractRequest();
    UUID milestoneId = acceptRequest(requestId, 1);
    org.junit.jupiter.api.Assertions.assertEquals(201, submitMilestone(milestoneId, creator)
        .getResponse().getStatus());

    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.post("/api/milestones/" + milestoneId + "/disputes")
                    .contentType("application/json")
                    .content("{\"reason\":\"\"}"),
                listener))
        .andExpect(status().isBadRequest());
    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.post("/api/milestones/" + milestoneId + "/disputes")
                    .contentType("application/json")
                    .content(objectMapper.writeValueAsBytes(Map.of("reason", "x".repeat(5001)))),
                listener))
        .andExpect(status().isBadRequest());
    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.post("/api/milestones/" + milestoneId + "/disputes")
                    .contentType("application/json")
                    .content("{\"reason\":\"Requesting a review\"}"),
                otherListener))
        .andExpect(status().isConflict());

    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.post("/api/milestones/" + milestoneId + "/disputes")
                    .contentType("application/json")
                    .content("{\"reason\":\"Requesting a review\"}"),
                listener))
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.status").value("OPEN"));
    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.post("/api/milestones/" + milestoneId + "/disputes")
                    .contentType("application/json")
                    .content("{\"reason\":\"Duplicate review\"}"),
                listener))
        .andExpect(status().isConflict());
  }

  @Test
  void enforcesContractDisputeOwnerReasonAndDuplicateRules() throws Exception {
    UUID requestId = createContractRequest();
    acceptRequest(requestId, 1);
    Contract contract =
        contractRepository
            .findBySeriesResponse_SeriesRequest_SeriesRequestId(requestId)
            .orElseThrow();
    String path = "/api/contracts/" + contract.getContractId() + "/disputes";

    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.post(path)
                    .contentType("application/json")
                    .content("{\"note\":\"\"}"),
                listener))
        .andExpect(status().isBadRequest());
    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.post(path)
                    .contentType("application/json")
                    .content(objectMapper.writeValueAsBytes(Map.of("note", "x".repeat(5001)))),
                listener))
        .andExpect(status().isBadRequest());
    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.post(path)
                    .contentType("application/json")
                    .content("{\"note\":\"Not a participant\"}"),
                otherListener))
        .andExpect(status().isForbidden());

    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.post(path)
                    .contentType("application/json")
                    .content("{\"note\":\"Contract issue\"}"),
                listener))
        .andExpect(status().isCreated());
    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.post(path)
                    .contentType("application/json")
                    .content("{\"note\":\"Duplicate issue\"}"),
                listener))
        .andExpect(status().isConflict());
    mockMvc
        .perform(as(MockMvcRequestBuilders.get("/api/me/disputes?page=0&size=20"), listener))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.content", hasSize(1)));
    mockMvc
        .perform(as(MockMvcRequestBuilders.get("/api/me/disputes?page=0&size=20"), otherListener))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.content", hasSize(0)));
  }

  @Test
  void requiresAuthenticationForRequestAndDisputeEndpoints() throws Exception {
    mockMvc
        .perform(MockMvcRequestBuilders.get("/api/requests/me"))
        .andExpect(status().isUnauthorized());
    mockMvc
        .perform(MockMvcRequestBuilders.get("/api/me/disputes"))
        .andExpect(status().isUnauthorized());
  }
}
