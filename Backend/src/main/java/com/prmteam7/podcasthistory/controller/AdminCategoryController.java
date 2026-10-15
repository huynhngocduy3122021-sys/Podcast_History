package com.prmteam7.podcasthistory.controller;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.prmteam7.podcasthistory.dto.request.CategoryCreateRequest;
import com.prmteam7.podcasthistory.dto.request.CategoryUpdateRequest;
import com.prmteam7.podcasthistory.dto.response.CategoryResponse;
import com.prmteam7.podcasthistory.service.CategoryService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/admin/categories")
@Tag(name = "Admin - categories", description = "CRUD danh mục podcast")
@SecurityRequirement(name = "bearerAuth")
public class AdminCategoryController {

    private final CategoryService categoryService;

    public AdminCategoryController(CategoryService categoryService) {
        this.categoryService = categoryService;
    }

    @GetMapping
    @Operation(summary = "Danh sách tất cả category, bao gồm category đã vô hiệu hóa")
    public List<CategoryResponse> findAll() {
        return categoryService.findAll();
    }

    @GetMapping("/{categoryId}")
    @Operation(summary = "Xem chi tiết category")
    public CategoryResponse findById(@PathVariable UUID categoryId) {
        return categoryService.findById(categoryId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Tạo category")
    public CategoryResponse create(@Valid @RequestBody CategoryCreateRequest request) {
        return categoryService.create(request);
    }

    @PutMapping("/{categoryId}")
    @Operation(summary = "Cập nhật hoặc kích hoạt lại category")
    public CategoryResponse update(
            @PathVariable UUID categoryId,
            @Valid @RequestBody CategoryUpdateRequest request) {
        return categoryService.update(categoryId, request);
    }

    @DeleteMapping("/{categoryId}")
    @Operation(summary = "Vô hiệu hóa category để giữ liên kết podcast và series hiện có")
    public CategoryResponse deactivate(@PathVariable UUID categoryId) {
        return categoryService.deactivate(categoryId);
    }
}
