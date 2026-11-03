package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.prmteam7.podcasthistory.model.AiModerationResult;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

class ModerationResponseValidatorTest {
    private final ObjectMapper mapper = new ObjectMapper();

    @Test
    void acceptsSafeApproveWithValidConfidenceAndEvidence() throws Exception {
        var response = ModerationResponseValidator.validate(mapper.readTree(
                """{"label":"SAFE","recommendation":"APPROVE","confidence":0.95,"reason":"Nội dung an toàn","evidence":["Không phát hiện rủi ro"]}"""));

        assertEquals(new BigDecimal("0.95"), response.confidence());
        assertEquals("SAFE", response.label());
    }

    @Test
    void rejectsMissingInvalidOrOutOfRangeConfidence() {
        assertInvalid("{\"label\":\"SAFE\",\"recommendation\":\"APPROVE\",\"reason\":\"ok\",\"evidence\":[]}");
        assertInvalid("{\"label\":\"SAFE\",\"recommendation\":\"APPROVE\",\"confidence\":\"0.95\",\"reason\":\"ok\",\"evidence\":[]}");
        assertInvalid("{\"label\":\"SAFE\",\"recommendation\":\"APPROVE\",\"confidence\":-0.1,\"reason\":\"ok\",\"evidence\":[]}");
        assertInvalid("{\"label\":\"SAFE\",\"recommendation\":\"APPROVE\",\"confidence\":1.1,\"reason\":\"ok\",\"evidence\":[]}");
    }

    @Test
    void rejectsMalformedEnumsEvidenceAndReason() {
        assertInvalid("{\"label\":\"MAYBE\",\"recommendation\":\"APPROVE\",\"confidence\":0.95,\"reason\":\"ok\",\"evidence\":[]}");
        assertInvalid("{\"label\":\"SAFE\",\"recommendation\":\"APPROVE\",\"confidence\":0.95,\"reason\":\"ok\",\"evidence\":{}}");
        assertInvalid("{\"label\":\"SAFE\",\"recommendation\":\"APPROVE\",\"confidence\":0.95,\"reason\":\"\",\"evidence\":[]}");
        assertInvalid("{\"label\":\"SAFE\",\"recommendation\":\"APPROVE\",\"confidence\":0.95,\"reason\":\"ok\",\"evidence\":[1]}");
    }

    @Test
    void onlyConfidenceAtOrAboveConfiguredThresholdCanAutoApprove() {
        var result = new AiModerationResult();
        result.setStatus("COMPLETED");
        result.setOverallLabel("SAFE");
        result.setRecommendation("APPROVE");
        result.setConfidenceScore(new BigDecimal("0.90"));

        assertEquals(true, AiModerationService.isAutoApproveEligible(result, new BigDecimal("0.90")));
        result.setConfidenceScore(new BigDecimal("0.8999"));
        assertEquals(false, AiModerationService.isAutoApproveEligible(result, new BigDecimal("0.90")));
        result.setConfidenceScore(null);
        assertEquals(false, AiModerationService.isAutoApproveEligible(result, new BigDecimal("0.90")));
        result.setConfidenceScore(new BigDecimal("0.99"));
        result.setOverallLabel("UNSAFE");
        assertEquals(false, AiModerationService.isAutoApproveEligible(result, new BigDecimal("0.90")));
        result.setOverallLabel("SAFE");
        result.setRecommendation("REVIEW");
        assertEquals(false, AiModerationService.isAutoApproveEligible(result, new BigDecimal("0.90")));
    }

    private void assertInvalid(String json) {
        assertThrows(Exception.class, () -> ModerationResponseValidator.validate(mapper.readTree(json)));
    }
}
