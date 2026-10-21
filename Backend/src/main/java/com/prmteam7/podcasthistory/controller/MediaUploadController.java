package com.prmteam7.podcasthistory.controller;

import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.prmteam7.podcasthistory.dto.response.ApiError;
import com.prmteam7.podcasthistory.dto.response.MediaUploadResponse;
import com.prmteam7.podcasthistory.service.MediaUploadService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/uploads")
@Tag(name = "Media uploads", description = "Tải ảnh lên Cloudflare R2")
@SecurityRequirement(name = "bearerAuth")
public class MediaUploadController {

    private final MediaUploadService mediaUploadService;

    public MediaUploadController(MediaUploadService mediaUploadService) {
        this.mediaUploadService = mediaUploadService;
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Upload ảnh lên Cloudflare R2")
    @ApiResponse(
            responseCode = "201",
            description = "Upload thành công",
            content = @Content(schema = @Schema(implementation = MediaUploadResponse.class)))
    @ApiResponse(
            responseCode = "400",
            description = "File không hợp lệ",
            content = @Content(schema = @Schema(implementation = ApiError.class)))
    @ApiResponse(responseCode = "401", description = "Chưa đăng nhập")
    @ApiResponse(
            responseCode = "413",
            description = "File vượt quá giới hạn dung lượng",
            content = @Content(schema = @Schema(implementation = ApiError.class)))
    @ApiResponse(
            responseCode = "502",
            description = "Không thể tải file lên R2",
            content = @Content(schema = @Schema(implementation = ApiError.class)))
    @ApiResponse(
            responseCode = "503",
            description = "Chưa cấu hình R2",
            content = @Content(schema = @Schema(implementation = ApiError.class)))
    public ResponseEntity<MediaUploadResponse> upload(
            @AuthenticationPrincipal Jwt jwt,
            @RequestPart("file") MultipartFile file) {
        UUID userId = UUID.fromString(jwt.getClaimAsString("user_id"));
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(mediaUploadService.upload(file, userId));
    }
}
