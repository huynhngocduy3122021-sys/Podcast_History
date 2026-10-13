package com.prmteam7.podcasthistory.service;

import java.net.URI;
import java.time.Duration;
import java.time.Instant;

import org.springframework.stereotype.Service;

import com.prmteam7.podcasthistory.config.R2StorageProperties;
import com.prmteam7.podcasthistory.exception.MediaPlaybackException;
import com.prmteam7.podcasthistory.exception.R2NotConfiguredException;
import com.prmteam7.podcasthistory.exception.ResourceForbiddenException;

import jakarta.annotation.PreDestroy;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

@Service
public class R2PlaybackUrlService {

    private static final Duration URL_TTL = Duration.ofMinutes(5);

    private final R2StorageProperties properties;
    private volatile S3Presigner presigner;

    public R2PlaybackUrlService(R2StorageProperties properties) {
        this.properties = properties;
    }

    public PlaybackUrl create(String storedMediaUrl, boolean exclusive) {
        if (storedMediaUrl == null || storedMediaUrl.isBlank()) {
            throw new ResourceForbiddenException("Podcast chưa có file media để phát.");
        }

        if (isHttpUrl(storedMediaUrl)) {
            if (exclusive) {
                throw new ResourceForbiddenException(
                        "Podcast độc quyền phải lưu objectKey R2 để cấp URL có chữ ký.");
            }
            return new PlaybackUrl(storedMediaUrl, null);
        }

        if (!properties.isConfigured()) {
            throw new R2NotConfiguredException();
        }

        String objectKey = storedMediaUrl.trim().replaceFirst("^/+", "");

        try {
            var request = GetObjectRequest.builder()
                    .bucket(properties.getBucketName().trim())
                    .key(objectKey)
                    .build();
            var presignRequest = GetObjectPresignRequest.builder()
                    .signatureDuration(URL_TTL)
                    .getObjectRequest(request)
                    .build();
            String url = presigner().presignGetObject(presignRequest).url().toString();
            return new PlaybackUrl(url, Instant.now().plus(URL_TTL));
        } catch (RuntimeException exception) {
            throw new MediaPlaybackException(exception);
        }
    }

    private S3Presigner presigner() {
        S3Presigner current = presigner;
        if (current != null) {
            return current;
        }
        synchronized (this) {
            if (presigner == null) {
                presigner = S3Presigner.builder()
                        .endpointOverride(URI.create(properties.getEndpoint().trim()))
                        .region(Region.of(properties.getRegion()))
                        .credentialsProvider(StaticCredentialsProvider.create(AwsBasicCredentials.create(
                                properties.getAccessKeyId().trim(), properties.getSecretAccessKey().trim())))
                        .serviceConfiguration(S3Configuration.builder()
                                .pathStyleAccessEnabled(true)
                                .chunkedEncodingEnabled(false)
                                .build())
                        .build();
            }
            return presigner;
        }
    }

    private boolean isHttpUrl(String value) {
        return value.startsWith("https://") || value.startsWith("http://");
    }

    @PreDestroy
    void close() {
        if (presigner != null) {
            presigner.close();
        }
    }

    public record PlaybackUrl(String url, Instant expiresAt) {
    }
}
