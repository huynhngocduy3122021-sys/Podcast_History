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
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;

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

    public MediaUploadResponse uploadPodcastReferencePdf(
            MultipartFile file, UUID userId, UUID podcastId, UUID referenceId) {
        if (file == null || file.isEmpty()) {
            throw new InvalidMediaUploadException("Vui lòng chọn một file ảnh, video hoặc audio.");
        }
        s3Client().deleteObject(DeleteObjectRequest.builder()
                .bucket(properties.getBucketName().trim()).key(key).build());
    }

    private UploadFileType validateAndResolveFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new InvalidMediaUploadException("Vui lòng chọn file media.");
        }
        UploadFileType type = resolveFileType(file);
        validateSignature(file, type.contentType());
        return type;
    }

    private void validateSignature(MultipartFile file, String type) {
        try (var input = file.getInputStream()) {
            byte[] bytes = input.readNBytes(64);
            String ascii = new String(bytes, java.nio.charset.StandardCharsets.ISO_8859_1);
            boolean bmff = bytes.length >= 12 && ascii.startsWith("ftyp", 4);
            boolean valid = switch (type) {
                case "image/png" -> bytes.length >= 8 && java.util.Arrays.equals(
                        java.util.Arrays.copyOf(bytes, 8), new byte[]{(byte)137,80,78,71,13,10,26,10});
                case "image/jpeg" -> bytes.length >= 3 && (bytes[0]&255)==255 && (bytes[1]&255)==216 && (bytes[2]&255)==255;
                case "image/gif" -> ascii.startsWith("GIF87a") || ascii.startsWith("GIF89a");
                case "image/webp" -> ascii.startsWith("RIFF") && ascii.startsWith("WEBP",8);
                case "image/avif" -> bmff && (ascii.contains("avif") || ascii.contains("avis"));
                case "image/heic", "image/heif" -> bmff && (ascii.contains("heic") || ascii.contains("heix") || ascii.contains("mif1"));
                case "video/mp4", "video/quicktime", "video/x-m4v", "video/3gpp" -> bmff;
                case "video/webm", "video/x-matroska" -> bytes.length >= 4 && (bytes[0]&255)==26 && (bytes[1]&255)==69 && (bytes[2]&255)==223 && (bytes[3]&255)==163;
                case "video/x-msvideo", "video/avi" -> ascii.startsWith("RIFF") && ascii.startsWith("AVI ",8);
                default -> false;
            };
            if (!valid) throw new InvalidMediaUploadException("Nội dung file không khớp định dạng ảnh/video được hỗ trợ.");
        } catch (IOException exception) {
            throw new InvalidMediaUploadException("Không đọc được file media.");
        }
    }

    public void deletePodcastVideo(String key, UUID userId, UUID podcastId) {
        if (key == null || key.isBlank() || key.startsWith("http://") || key.startsWith("https://")) return;
        String prefix = normalizeFolder(properties.getFolder()) + "/" + userId + "/podcasts/" + podcastId + "/";
        if (!key.startsWith(prefix) || key.substring(prefix.length()).contains("/")) {
            throw new InvalidMediaUploadException("Object key không thuộc video của podcast này.");
        }
        s3Client().deleteObject(DeleteObjectRequest.builder().bucket(properties.getBucketName().trim()).key(key).build());
    }

    private MediaUploadResponse store(
            MultipartFile file, UUID userId, UUID podcastId, UploadFileType fileType) {
        return store(file, userId, podcastId, null, fileType);
    }

    private MediaUploadResponse store(
            MultipartFile file, UUID userId, UUID podcastId, UUID referenceId, UploadFileType fileType) {
        S3Client client = s3Client();
        Path tempFile = null;

        try {
            tempFile = Files.createTempFile("podcast-history-upload-", safeExtension(file.getOriginalFilename()));
            file.transferTo(tempFile.toFile());

            String objectKey = normalizeFolder(properties.getFolder()) + "/" + userId
                    + (podcastId == null ? "" : "/podcasts/" + podcastId)
                    + (referenceId == null ? "" : "/references/" + referenceId)
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
                    podcastId == null ? publicUrl(objectKey) : null,
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
            if (normalizedType.startsWith("audio/")) {
                return new UploadFileType(normalizedType);
            }
            if (!normalizedType.isBlank() && !normalizedType.equals("application/octet-stream")) {
                throw new InvalidMediaUploadException("Chỉ chấp nhận file ảnh, video hoặc audio.");
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
            case "mp3" -> new UploadFileType("audio/mpeg");
            case "m4a" -> new UploadFileType("audio/mp4");
            case "aac" -> new UploadFileType("audio/aac");
            case "wav" -> new UploadFileType("audio/wav");
            case "ogg", "oga" -> new UploadFileType("audio/ogg");
            case "opus" -> new UploadFileType("audio/opus");
            case "flac" -> new UploadFileType("audio/flac");
            default -> throw new InvalidMediaUploadException(
                    "Không xác định được file ảnh, video hoặc audio. Hãy gửi Content-Type hợp lệ.");
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
