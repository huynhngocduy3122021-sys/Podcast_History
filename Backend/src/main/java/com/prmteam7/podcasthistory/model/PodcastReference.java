package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "\"Podcast_reference\"", indexes = {
        @Index(name = "idx_podcast_reference_podcast_id", columnList = "podcast_id")
    })
public class PodcastReference extends BaseEntity {
    @Id
    @Column(name = "reference_id", nullable = false, updatable = false)
    private UUID referenceId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "podcast_id", nullable = false)
    private Podcast podcast;

    @Column(name = "reference_type", nullable = false, length = 30)
    private String referenceType;

    @Column(name = "title", nullable = false, length = 300)
    private String title;

    @Column(name = "author", nullable = true, length = 200)
    private String author;

    @Column(name = "publisher", nullable = true, length = 200)
    private String publisher;

    @Column(name = "published_year", nullable = true)
    private Integer publishedYear;

    @Column(name = "url", nullable = true, columnDefinition = "text")
    private String url;

    @Column(name = "file_url", nullable = true, columnDefinition = "text")
    private String fileUrl;

    @Column(name = "citation_text", nullable = true, columnDefinition = "text")
    private String citationText;

    public PodcastReference() {
    }

    @PrePersist
    private void assignId() {
        if (referenceId == null) {
            referenceId = UUID.randomUUID();
        }
    }

    public UUID getReferenceId() {
        return referenceId;
    }

    public void setReferenceId(UUID referenceId) {
        this.referenceId = referenceId;
    }

    public Podcast getPodcast() {
        return podcast;
    }

    public void setPodcast(Podcast podcast) {
        this.podcast = podcast;
    }

    public String getReferenceType() {
        return referenceType;
    }

    public void setReferenceType(String referenceType) {
        this.referenceType = referenceType;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getAuthor() {
        return author;
    }

    public void setAuthor(String author) {
        this.author = author;
    }

    public String getPublisher() {
        return publisher;
    }

    public void setPublisher(String publisher) {
        this.publisher = publisher;
    }

    public Integer getPublishedYear() {
        return publishedYear;
    }

    public void setPublishedYear(Integer publishedYear) {
        this.publishedYear = publishedYear;
    }

    public String getUrl() {
        return url;
    }

    public void setUrl(String url) {
        this.url = url;
    }

    public String getFileUrl() {
        return fileUrl;
    }

    public void setFileUrl(String fileUrl) {
        this.fileUrl = fileUrl;
    }

    public String getCitationText() {
        return citationText;
    }

    public void setCitationText(String citationText) {
        this.citationText = citationText;
    }

}
