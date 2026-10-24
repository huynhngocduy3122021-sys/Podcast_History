package com.prmteam7.podcasthistory.service;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

@Service
public class WhisperTranscriptionClient {
    private final URI endpoint;
    private final String token;
    private final R2PlaybackUrlService playback;
    private final ObjectMapper mapper;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();

    public WhisperTranscriptionClient(
            @Value("${whisper.service-url:http://127.0.0.1:8092}") String serviceUrl,
            @Value("${whisper.service-token:}") String token,
            R2PlaybackUrlService playback, ObjectMapper mapper) {
        this.endpoint = URI.create(serviceUrl.replaceAll("/+$", "") + "/transcribe");
        this.token = token;
        this.playback = playback;
        this.mapper = mapper;
    }

    public JsonNode transcribe(String mediaKey) throws IOException, InterruptedException {
        if (mediaKey == null || mediaKey.startsWith("http://") || mediaKey.startsWith("https://"))
            throw new IllegalArgumentException("Phiên âm chỉ hỗ trợ object key R2.");
        String url = playback.create(mediaKey, true).url();
        HttpRequest.Builder request = HttpRequest.newBuilder(endpoint)
                .timeout(Duration.ofMinutes(20))
                .header("Content-Type", "application/json");
        if (!token.isBlank()) request.header("Authorization", "Bearer " + token);
        HttpResponse<String> response = http.send(request.POST(HttpRequest.BodyPublishers.ofString(
                mapper.writeValueAsString(Map.of("mediaUrl", url)))).build(),
                HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200)
            throw new IOException("whisper-service trả HTTP " + response.statusCode());
        JsonNode output = mapper.readTree(response.body());
        if (!output.path("segments").isArray() || output.path("fullText").isMissingNode())
            throw new IOException("whisper-service trả transcript không hợp lệ.");
        return output;
    }
}
