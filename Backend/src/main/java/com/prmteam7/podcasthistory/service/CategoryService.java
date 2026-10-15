package com.prmteam7.podcasthistory.service;

import java.util.List;
import java.util.Locale;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.prmteam7.podcasthistory.dto.request.CategoryCreateRequest;
import com.prmteam7.podcasthistory.dto.request.CategoryUpdateRequest;
import com.prmteam7.podcasthistory.dto.response.CategoryResponse;
import com.prmteam7.podcasthistory.exception.InvalidFlowRequestException;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.exception.ResourceNotFoundException;
import com.prmteam7.podcasthistory.model.Category;
import com.prmteam7.podcasthistory.repository.CategoryRepository;

@Service
public class CategoryService {

    private final CategoryRepository categoryRepository;

    public CategoryService(CategoryRepository categoryRepository) {
        this.categoryRepository = categoryRepository;
    }

    @Transactional(readOnly = true)
    public List<CategoryResponse> findAll() {
        return categoryRepository.findAllByOrderByNameAsc().stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public CategoryResponse findById(UUID categoryId) {
        return toResponse(requireCategory(categoryId));
    }

    @Transactional
    public CategoryResponse create(CategoryCreateRequest request) {
        String name = request.name().trim();
        String slug = normalizeSlug(request.slug());
        requireUnique(name, slug, null);

        Category category = new Category();
        category.setName(name);
        category.setSlug(slug);
        category.setDescription(trimToNull(request.description()));
        category.setIsActive(request.active() == null || request.active());
        return toResponse(categoryRepository.save(category));
    }

    @Transactional
    public CategoryResponse update(UUID categoryId, CategoryUpdateRequest request) {
        Category category = requireCategory(categoryId);
        String name = request.name().trim();
        String slug = normalizeSlug(request.slug());
        requireUnique(name, slug, categoryId);

        category.setName(name);
        category.setSlug(slug);
        category.setDescription(trimToNull(request.description()));
        category.setIsActive(request.active());
        return toResponse(categoryRepository.save(category));
    }

    @Transactional
    public CategoryResponse deactivate(UUID categoryId) {
        Category category = requireCategory(categoryId);
        category.setIsActive(false);
        return toResponse(categoryRepository.save(category));
    }

    private Category requireCategory(UUID categoryId) {
        return categoryRepository.findById(categoryId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy category."));
    }

    private void requireUnique(String name, String slug, UUID currentCategoryId) {
        boolean duplicatedName = currentCategoryId == null
                ? categoryRepository.existsByNameIgnoreCase(name)
                : categoryRepository.existsByNameIgnoreCaseAndCategoryIdNot(name, currentCategoryId);
        if (duplicatedName) {
            throw new ResourceConflictException("Tên category đã được sử dụng.");
        }

        boolean duplicatedSlug = currentCategoryId == null
                ? categoryRepository.existsBySlugIgnoreCase(slug)
                : categoryRepository.existsBySlugIgnoreCaseAndCategoryIdNot(slug, currentCategoryId);
        if (duplicatedSlug) {
            throw new ResourceConflictException("Slug category đã được sử dụng.");
        }
    }

    private String normalizeSlug(String value) {
        String slug = value.trim().toLowerCase(Locale.ROOT)
                .replaceAll("[^\\p{L}\\p{N}]+", "-")
                .replaceAll("^-|-$", "");
        if (slug.isBlank()) {
            throw new InvalidFlowRequestException("Slug category không hợp lệ.");
        }
        return slug;
    }

    private String trimToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private CategoryResponse toResponse(Category category) {
        return new CategoryResponse(
                category.getCategoryId(),
                category.getName(),
                category.getSlug(),
                category.getDescription(),
                category.getIsActive(),
                category.getCreatedAt(),
                category.getUpdatedAt());
    }
}
