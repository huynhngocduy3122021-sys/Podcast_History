package com.prmteam7.podcasthistory.service;

import java.io.IOException;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.UUID;

import jakarta.annotation.PreDestroy;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import com.prmteam7.podcasthistory.config.R2StorageProperties;
import com.prmteam7.podcasthistory.dto.response.MediaUploadResponse;
import com.prmteam7.podcasthistory.exception.R2NotConfiguredException;
import com.prmteam7.podcasthistory.exception.R2UploadException;
import com.prmteam7.podcasthistory.exception.InvalidMediaUploadException;

import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

@Service
public class MediaUploadService {

    private final R2StorageProperties properties;
    private volatile S3Client s3Client;

    public MediaUploadService(R2StorageProperties properties) {
        this.properties = properties;
    }

    public MediaUploadResponse upload(MultipartFile file, UUID userId) {
        UploadFileType fileType = validateAndResolveFile(file);
        if (!fileType.contentType().startsWith("image/")) {
            throw new InvalidMediaUploadException(
                    "Video phải được upload qua API của podcast để liên kết đúng podcast.");
        }
        return store(file, userId, null, fileType);
    }

    public MediaUploadResponse uploadPodcastVideo(MultipartFile file, UUID userId, UUID podcastId) {
        UploadFileType fileType = validateAndResolveFile(file);
        if (!fileType.contentType().startsWith("video/")) {
            throw new InvalidMediaUploadException("API này chỉ chấp nhận file video.");
        }
        return store(file, userId, podcastId, fileType);
    }

    private UploadFileType validateAndResolveFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new InvalidMediaUploadException("Vui lòng chọn file media.");
        }
        return resolveFileType(file);
    }

    private MediaUploadResponse store(
            MultipartFile file, UUID userId, UUID podcastId, UploadFileType fileType) {
        S3Client client = s3Client();
        Path tempFile = null;

        try {
            tempFile = Files.createTempFile("podcast-history-upload-", safeExtension(file.getOriginalFilename()));
            file.transferTo(tempFile.toFile());

            String objectKey = normalizeFolder(properties.getFolder()) + "/" + userId
                    + (podcastId == null ? "" : "/podcasts/" + podcastId)
                    + "/" + UUID.randomUUID() + safeExtension(file.getOriginalFilename());
            PutObjectRequest request = PutObjectRequest.builder()
                    .bucket(properties.getBucketName().trim())
                    .key(objectKey)
                    .contentType(fileType.contentType())
                    .build();
            client.putObject(request, RequestBody.fromFile(tempFile.toFile()));

            return new MediaUploadResponse(
                    objectKey,
                    properties.getBucketName().trim(),
                    publicUrl(objectKey),
                    fileType.contentType(),
                    file.getSize());
        } catch (IOException | RuntimeException exception) {
            throw new R2UploadException(exception);
        } finally {
            if (tempFile != null) {
                try {
                    Files.deleteIfExists(tempFile);
                } catch (IOException ignored) {
                    // The operating system will remove the temporary upload file later.
                }
            }
        }
    }

    private S3Client s3Client() {
        if (!properties.isConfigured()) {
            throw new R2NotConfiguredException();
        }
        if (s3Client == null) {
            synchronized (this) {
                if (s3Client == null) {
                    try {
                        s3Client = S3Client.builder()
                                .endpointOverride(URI.create(properties.getEndpoint().trim()))
                                .credentialsProvider(StaticCredentialsProvider.create(AwsBasicCredentials.create(
                                        properties.getAccessKeyId().trim(),
                                        properties.getSecretAccessKey().trim())))
                                .region(Region.of(normalizeRegion(properties.getRegion())))
                                .serviceConfiguration(S3Configuration.builder()
                                        .pathStyleAccessEnabled(true)
                                        .chunkedEncodingEnabled(false)
                                        .build())
                                .build();
                    } catch (RuntimeException exception) {
                        throw new R2UploadException(exception);
                    }
                }
            }
        }
        return s3Client;
    }

    private UploadFileType resolveFileType(MultipartFile file) {
        String contentType = file.getContentType();
        if (contentType != null) {
            String normalizedType = contentType.toLowerCase(Locale.ROOT).split(";", 2)[0].trim();
            if (normalizedType.startsWith("image/") && !normalizedType.equals("image/svg+xml")) {
                return new UploadFileType(normalizedType);
            }
            if (normalizedType.startsWith("video/")) {
                return new UploadFileType(normalizedType);
            }
            if (!normalizedType.isBlank() && !normalizedType.equals("application/octet-stream")) {
                throw new InvalidMediaUploadException("Chỉ chấp nhận file ảnh hoặc video.");
            }
        }

        String extension = extensionOf(file.getOriginalFilename());
        return switch (extension) {
            case "jpg", "jpeg" -> new UploadFileType("image/jpeg");
            case "png" -> new UploadFileType("image/png");
            case "webp" -> new UploadFileType("image/webp");
            case "gif" -> new UploadFileType("image/gif");
            case "avif" -> new UploadFileType("image/avif");
            case "heic" -> new UploadFileType("image/heic");
            case "heif" -> new UploadFileType("image/heif");
            case "mp4" -> new UploadFileType("video/mp4");
            case "mov" -> new UploadFileType("video/quicktime");
            case "m4v" -> new UploadFileType("video/x-m4v");
            case "webm" -> new UploadFileType("video/webm");
            case "mkv" -> new UploadFileType("video/x-matroska");
            case "3gp" -> new UploadFileType("video/3gpp");
            case "avi" -> new UploadFileType("video/x-msvideo");
            default -> throw new InvalidMediaUploadException(
                    "Không xác định được file ảnh hoặc video. Hãy gửi Content-Type hợp lệ.");
        };
    }

    private String publicUrl(String objectKey) {
        String baseUrl = properties.getPublicBaseUrl();
        if (baseUrl == null || baseUrl.isBlank()) {
            return null;
        }
        return baseUrl.trim().replaceAll("/+$", "") + "/" + objectKey;
    }

    private String normalizeFolder(String folder) {
        if (folder == null || folder.isBlank()) {
            return "podcast-history";
        }
        String normalized = folder.trim()
                .replace('\\', '/')
                .replaceAll("[^A-Za-z0-9/_-]+", "-")
                .replaceAll("/+/", "/")
                .replaceAll("^/+|/+$", "");
        return normalized.isBlank() ? "podcast-history" : normalized;
    }

    private String normalizeRegion(String region) {
        return region == null || region.isBlank() ? "auto" : region.trim();
    }

    private String safeExtension(String filename) {
        String extension = extensionOf(filename);
        return extension.isBlank() ? ".bin" : "." + extension;
    }

    private String extensionOf(String filename) {
        if (filename == null) {
            return "";
        }
        String normalized = filename.toLowerCase(Locale.ROOT);
        int separatorIndex = Math.max(normalized.lastIndexOf('/'), normalized.lastIndexOf('\\'));
        int dotIndex = normalized.lastIndexOf('.');
        if (dotIndex <= separatorIndex || dotIndex == normalized.length() - 1) {
            return "";
        }
        String extension = normalized.substring(dotIndex + 1);
        return extension.matches("[a-z0-9]{1,10}") ? extension : "";
    }

    @PreDestroy
    public void closeClient() {
        if (s3Client != null) {
            s3Client.close();
        }
    }

    private record UploadFileType(String contentType) {
    }
}
