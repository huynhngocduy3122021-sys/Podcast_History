package com.prmteam7.podcasthistory.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "r2")
public class R2StorageProperties {

    private String endpoint = "";
    private String accessKeyId = "";
    private String secretAccessKey = "";
    private String bucketName = "";
    private String region = "auto";
    private String folder = "podcast-history";
    private String publicBaseUrl = "";

    public String getEndpoint() {
        return endpoint;
    }

    public void setEndpoint(String endpoint) {
        this.endpoint = endpoint;
    }

    public String getAccessKeyId() {
        return accessKeyId;
    }

    public void setAccessKeyId(String accessKeyId) {
        this.accessKeyId = accessKeyId;
    }

    public String getSecretAccessKey() {
        return secretAccessKey;
    }

    public void setSecretAccessKey(String secretAccessKey) {
        this.secretAccessKey = secretAccessKey;
    }

    public String getBucketName() {
        return bucketName;
    }

    public void setBucketName(String bucketName) {
        this.bucketName = bucketName;
    }

    public String getRegion() {
        return region;
    }

    public void setRegion(String region) {
        this.region = region;
    }

    public String getFolder() {
        return folder;
    }

    public void setFolder(String folder) {
        this.folder = folder;
    }

    public String getPublicBaseUrl() {
        return publicBaseUrl;
    }

    public void setPublicBaseUrl(String publicBaseUrl) {
        this.publicBaseUrl = publicBaseUrl;
    }

    public boolean isConfigured() {
        return hasText(endpoint)
                && hasText(accessKeyId)
                && hasText(secretAccessKey)
                && hasText(bucketName);
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }
}
