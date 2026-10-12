package com.prmteam7.podcasthistory.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "Thông tin media sau khi tải lên Cloudflare R2")
public record MediaUploadResponse(
        @Schema(description = "Object key lưu trong bucket R2; nên lưu key này vào database")
        String objectKey,
        String bucket,
        @Schema(description = "URL public nếu bucket đã cấu hình R2.dev hoặc custom domain; null nếu bucket private")
        String publicUrl,
        String contentType,
        Long bytes) {
}
