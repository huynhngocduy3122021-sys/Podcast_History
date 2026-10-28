package com.prmteam7.podcasthistory.dto.request;

import java.util.UUID;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public final class ListenerRequests {

    private ListenerRequests() {
    }

    public record ListeningProgress(
            @NotNull @Min(0) @Max(86400) Integer progressSeconds,
            @NotNull Boolean completed) {
    }

    public record CommentCreate(
            @NotBlank @Size(max = 5000) String content,
            @Min(0)
            @io.swagger.v3.oas.annotations.media.Schema(
                    description = "Vị trí player tại lúc gửi bình luận, tính bằng giây; null là bình luận không gắn mốc thời gian. Frontend gửi currentPosition, không phải thời gian đồng hồ.",
                    example = "1080", minimum = "0")
            Integer timestampSeconds) {
    }

    public record CommentUpdate(
            @NotBlank @Size(max = 5000) String content) {
    }

    public record ReportCreate(
            @NotBlank @Size(max = 20) String targetType,
            @NotNull UUID targetId,
            @NotBlank @Size(max = 50) String reasonCode,
            @Size(max = 5000) String description) {
    }

    public record ReportUpdate(
            @NotBlank @Size(max = 50) String reasonCode,
            @Size(max = 5000) String description) {
    }

    public record MembershipCheckout(
            @NotNull UUID membershipPlanId,
            @Pattern(regexp = "SEPAY|WALLET") String paymentMethod) {
    }

    public record SeriesRequestCreate(
            @NotBlank @Size(max = 220) String requestedTitle,
            @NotBlank @Size(max = 10000) String description) {
    }

    public record SeriesRequestUpdate(
            @NotBlank @Size(max = 220) String requestedTitle,
            @NotBlank @Size(max = 10000) String description) {
    }
}
