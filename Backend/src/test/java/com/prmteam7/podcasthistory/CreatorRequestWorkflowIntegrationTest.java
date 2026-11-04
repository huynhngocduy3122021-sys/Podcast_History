package com.prmteam7.podcasthistory;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.prmteam7.podcasthistory.model.Payment;
import com.prmteam7.podcasthistory.repository.ContractRepository;
import com.prmteam7.podcasthistory.repository.PaymentRepository;
import com.prmteam7.podcasthistory.repository.SeriesRequestRepository;
import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

class CreatorRequestWorkflowIntegrationTest extends CreatorRequestIntegrationTestBase {
  @Autowired private SeriesRequestRepository seriesRequestRepository;
  @Autowired private ContractRepository contractRepository;
  @Autowired private PaymentRepository paymentRepository;

  @Test
  void completesContractRequestHandoffAndPendingApprovalFlow() throws Exception {
    UUID requestId = createContractRequest();

    mockMvc
        .perform(as(MockMvcRequestBuilders.get("/api/requests/me"), listener))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$[0].requestId").value(requestId.toString()))
        .andExpect(jsonPath("$[0].status").value("PENDING"));

    UUID milestoneId = acceptRequest(requestId, 1);
    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.get("/api/requests/" + requestId + "/milestones"),
                listener))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$", hasSize(1)))
        .andExpect(jsonPath("$[0].milestoneId").value(milestoneId.toString()))
        .andExpect(jsonPath("$[0].status").value("NOT_STARTED"))
        .andExpect(jsonPath("$[0].amount").value(100.0));

    MvcResult handoff = submitMilestone(milestoneId, creator);
    org.junit.jupiter.api.Assertions.assertEquals(201, handoff.getResponse().getStatus());
    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.get(
                    "/api/milestones/" + milestoneId + "/submissions"),
                listener))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$", hasSize(1)))
        .andExpect(jsonPath("$[0].milestoneId").value(milestoneId.toString()));

    MvcResult approval =
        mockMvc
            .perform(
                as(
                    MockMvcRequestBuilders.post(
                        "/api/listener/milestones/" + milestoneId + "/approve"),
                    listener))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.milestoneId").value(milestoneId.toString()))
            .andExpect(jsonPath("$.paymentStatus").value("PENDING"))
            .andReturn();

    JsonNode approvalBody = objectMapper.readTree(approval.getResponse().getContentAsByteArray());
    UUID paymentId = UUID.fromString(approvalBody.get("paymentId").asText());
    Payment payment = paymentRepository.findById(paymentId).orElseThrow();
    org.junit.jupiter.api.Assertions.assertEquals("PENDING", payment.getStatus());
    org.junit.jupiter.api.Assertions.assertEquals(
        0, payment.getAmount().compareTo(new BigDecimal("100.00")));
    org.junit.jupiter.api.Assertions.assertNull(payment.getProvider());
    org.junit.jupiter.api.Assertions.assertNull(payment.getPaymentCode());

    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.get("/api/requests/" + requestId + "/milestones"),
                listener))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$[0].paymentId").value(paymentId.toString()));

    org.junit.jupiter.api.Assertions.assertEquals(
        "ACCEPTED", seriesRequestRepository.findById(requestId).orElseThrow().getStatus());
    org.junit.jupiter.api.Assertions.assertTrue(
        contractRepository.findBySeriesResponse_SeriesRequest_SeriesRequestId(requestId).isPresent());
  }

  @Test
  void rejectsInvalidContractRequestPayloadsWithBadRequest() throws Exception {
    assertBadRequest(Map.of("creatorProfileId", creatorProfile.getProducerProfileId(),
        "requestedTitle", "", "description", "details"));
    assertBadRequest(Map.of("creatorProfileId", creatorProfile.getProducerProfileId(),
        "requestedTitle", "x".repeat(221), "description", "details"));
    assertBadRequest(Map.of("creatorProfileId", creatorProfile.getProducerProfileId(),
        "requestedTitle", "Title", "description", ""));
    assertBadRequest(Map.of("creatorProfileId", creatorProfile.getProducerProfileId(),
        "requestedTitle", "Title", "description", "x".repeat(5001)));

    for (String fee : new String[] {"-0.01", "10000000000.00", "1.001"}) {
      String json =
          """
          {"creatorProfileId":"%s","requestedTitle":"Title","description":"Details","requestFee":%s,"currency":"VND"}
          """
              .formatted(creatorProfile.getProducerProfileId(), fee);
      mockMvc
          .perform(
              as(
                  MockMvcRequestBuilders.post("/api/requests")
                      .contentType(MediaType.APPLICATION_JSON)
                      .content(json),
                  listener))
          .andExpect(status().isBadRequest());
    }

    for (String currency : new String[] {"US", "USDD"}) {
      mockMvc
          .perform(
              as(
                  MockMvcRequestBuilders.post("/api/requests")
                      .contentType(MediaType.APPLICATION_JSON)
                      .content(
                          objectMapper.writeValueAsBytes(
                              Map.of(
                                  "creatorProfileId", creatorProfile.getProducerProfileId(),
                                  "requestedTitle", "Title",
                                  "description", "Details",
                                  "currency", currency))),
                  listener))
          .andExpect(status().isBadRequest());
    }

    org.junit.jupiter.api.Assertions.assertEquals(0, seriesRequestRepository.count());
  }

  @Test
  void validatesAuthorizationWorkflowStateAndRevisionReason() throws Exception {
    UUID requestId = createContractRequest();
    UUID milestoneId = acceptRequest(requestId, 1);

    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.get("/api/requests/" + requestId + "/milestones"),
                otherListener))
        .andExpect(status().isConflict());
    org.junit.jupiter.api.Assertions.assertEquals(
        409,
        postJson(
                "/api/creator/requests/" + requestId + "/accept",
                otherCreator,
                Map.of(
                    "responseText", "Not mine",
                    "milestones",
                    java.util.List.of(Map.of("name", "Other", "amount", 1))))
            .getResponse()
            .getStatus());
    org.junit.jupiter.api.Assertions.assertEquals(
        409,
        mockMvc
            .perform(
                as(
                    MockMvcRequestBuilders.post(
                        "/api/listener/milestones/" + milestoneId + "/approve"),
                    listener))
            .andReturn()
            .getResponse()
            .getStatus());

    org.junit.jupiter.api.Assertions.assertEquals(
        401,
        mockMvc
            .perform(MockMvcRequestBuilders.get("/api/requests/me"))
            .andReturn()
            .getResponse()
            .getStatus());
    org.junit.jupiter.api.Assertions.assertEquals(
        401,
        mockMvc
            .perform(
                MockMvcRequestBuilders.get("/api/requests/me")
                    .header("Authorization", "Bearer invalid-token"))
            .andReturn()
            .getResponse()
            .getStatus());

    org.junit.jupiter.api.Assertions.assertEquals(201, submitMilestone(milestoneId, creator)
        .getResponse().getStatus());
    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.post(
                        "/api/listener/milestones/" + milestoneId + "/revision")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{\"reason\":\"\"}"),
                listener))
        .andExpect(status().isBadRequest());
    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.post(
                        "/api/listener/milestones/" + milestoneId + "/revision")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        objectMapper.writeValueAsBytes(Map.of("reason", "x".repeat(5001)))),
                listener))
        .andExpect(status().isBadRequest());
    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.post(
                        "/api/listener/milestones/" + milestoneId + "/revision")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("{\"reason\":\"Please revise the audio\"}"),
                listener))
        .andExpect(status().isNoContent());
    org.junit.jupiter.api.Assertions.assertEquals(
        409,
        mockMvc
            .perform(
                as(
                    MockMvcRequestBuilders.post(
                        "/api/listener/milestones/" + milestoneId + "/approve"),
                    listener))
            .andReturn()
            .getResponse()
            .getStatus());
  }

  @Test
  void reportsOversizedSubmissionNoteAsBadRequest() throws Exception {
    UUID requestId = createContractRequest();
    UUID milestoneId = acceptRequest(requestId, 1);
    MockMultipartFile file =
        new MockMultipartFile(
            "file", "submission.mp4", "video/mp4", new byte[] {0, 0, 0, 24, 102, 116, 121, 112});

    mockMvc
        .perform(
            as(
                MockMvcRequestBuilders.multipart(
                        "/api/creator/milestones/" + milestoneId + "/submissions")
                    .file(file)
                    .param("note", "x".repeat(5001)),
                creator))
        .andExpect(status().isBadRequest());
  }

  private void assertBadRequest(Object body) throws Exception {
    org.junit.jupiter.api.Assertions.assertEquals(
        400, postJson("/api/requests", listener, body).getResponse().getStatus());
  }
}
