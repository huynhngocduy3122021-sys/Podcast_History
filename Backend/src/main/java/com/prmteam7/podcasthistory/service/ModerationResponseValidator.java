package com.prmteam7.podcasthistory.service;

import java.math.BigDecimal;
import tools.jackson.databind.JsonNode;

final class ModerationResponseValidator {
    static final BigDecimal ZERO = BigDecimal.ZERO;
    static final BigDecimal ONE = BigDecimal.ONE;
    static final int MAX_REASON_LENGTH = 2000;

    private ModerationResponseValidator() {}

    static Validated validate(JsonNode output) {
        if (output == null || !output.isObject()) {
            throw new IllegalArgumentException("Gemini trả moderation response không phải JSON object.");
        }
        for (String field : new String[]{"label", "recommendation", "confidence", "reason", "evidence"}) {
            if (!output.has(field) || output.get(field).isNull()) {
                throw new IllegalArgumentException("Gemini thiếu trường bắt buộc: " + field + ".");
            }
        }

        String label = allowed(output.path("label").asText(), "SAFE", "UNSAFE", "UNCERTAIN");
        String recommendation = allowed(output.path("recommendation").asText(), "APPROVE", "REJECT", "REVIEW");
        if (label == null || recommendation == null) {
            throw new IllegalArgumentException("Gemini trả nhãn kiểm duyệt không hợp lệ.");
        }

        JsonNode confidenceNode = output.path("confidence");
        if (!confidenceNode.isNumber()) {
            throw new IllegalArgumentException("Gemini trả confidence không phải số.");
        }
        BigDecimal confidence;
        try {
            confidence = confidenceNode.decimalValue();
        } catch (RuntimeException exception) {
            throw new IllegalArgumentException("Gemini trả confidence không hợp lệ.", exception);
        }
        if (confidence.compareTo(ZERO) < 0 || confidence.compareTo(ONE) > 0) {
            throw new IllegalArgumentException("Gemini trả confidence ngoài khoảng 0.0..1.0.");
        }

        String reason = output.path("reason").asText();
        if (reason.isBlank() || reason.length() > MAX_REASON_LENGTH) {
            throw new IllegalArgumentException("Gemini trả lý do kiểm duyệt không hợp lệ.");
        }
        JsonNode evidence = output.path("evidence");
        if (!evidence.isArray()) {
            throw new IllegalArgumentException("Gemini trả bằng chứng kiểm duyệt không hợp lệ.");
        }
        for (JsonNode item : evidence) {
            if (!item.isTextual()) {
                throw new IllegalArgumentException("Gemini trả bằng chứng kiểm duyệt sai kiểu.");
            }
        }
        return new Validated(label, recommendation, confidence, reason, evidence);
    }

    private static String allowed(String value, String... choices) {
        for (String choice : choices) if (choice.equals(value)) return value;
        return null;
    }

    record Validated(String label, String recommendation, BigDecimal confidence,
            String reason, JsonNode evidence) {}
}
