package com.prmteam7.podcasthistory.controller;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.prmteam7.podcasthistory.dto.response.ListenerResponses.CategoryItem;
import com.prmteam7.podcasthistory.service.ListenerFlowService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController
@RequestMapping("/api/categories")
@Tag(name = "Categories", description = "Danh mục podcast công khai")
public class CategoryController {

    private final ListenerFlowService listenerFlowService;

    public CategoryController(ListenerFlowService listenerFlowService) {
        this.listenerFlowService = listenerFlowService;
    }

    @GetMapping
    @Operation(summary = "Danh sách category đang hoạt động, không cần đăng nhập")
    public List<CategoryItem> getCategories() {
        return listenerFlowService.getCategories();
    }
}
