package com.prmteam7.podcasthistory.repository;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.Category;

public interface CategoryRepository extends JpaRepository<Category, UUID> {

    List<Category> findAllByIsActiveTrueOrderByNameAsc();
}
