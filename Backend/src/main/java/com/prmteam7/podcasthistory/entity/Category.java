package com.prmteam7.podcasthistory.entity;

import jakarta.persistence.*;
import com.prmteam7.podcasthistory.entity.BaseEntity;
import com.prmteam7.podcasthistory.entity.UpdatedEntity;
import java.util.UUID;

@Entity
@Table(name = "category", uniqueConstraints = {
        @UniqueConstraint(name = "uk_category_name", columnNames = {"name"}),
        @UniqueConstraint(name = "uk_category_slug", columnNames = {"slug"})
    })
public class Category extends UpdatedEntity {
    @Id
    @Column(name = "category_id", nullable = false, updatable = false)
    private UUID categoryId;

    @Column(name = "name", nullable = false, length = 120)
    private String name;

    @Column(name = "slug", nullable = false, length = 140)
    private String slug;

    @Column(name = "description", nullable = true, columnDefinition = "text")
    private String description;

    @Column(name = "is_active", nullable = false)
    private Boolean isActive;

    public Category() {
    }

    @PrePersist
    private void assignId() {
        if (categoryId == null) {
            categoryId = UUID.randomUUID();
        }
    }

    public UUID getCategoryId() {
        return categoryId;
    }

    public void setCategoryId(UUID categoryId) {
        this.categoryId = categoryId;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getSlug() {
        return slug;
    }

    public void setSlug(String slug) {
        this.slug = slug;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public Boolean getIsActive() {
        return isActive;
    }

    public void setIsActive(Boolean isActive) {
        this.isActive = isActive;
    }

}
