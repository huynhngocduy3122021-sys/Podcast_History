package com.prmteam7.podcasthistory.repository;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.Category;

public interface CategoryRepository extends JpaRepository<Category, UUID> {

    List<Category> findAllByIsActiveTrueOrderByNameAsc();

    List<Category> findAllByOrderByNameAsc();

    boolean existsByNameIgnoreCase(String name);

    boolean existsByNameIgnoreCaseAndCategoryIdNot(String name, UUID categoryId);

    boolean existsBySlugIgnoreCase(String slug);

    boolean existsBySlugIgnoreCaseAndCategoryIdNot(String slug, UUID categoryId);
}
