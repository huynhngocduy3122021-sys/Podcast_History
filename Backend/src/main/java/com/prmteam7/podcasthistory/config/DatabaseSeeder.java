package com.prmteam7.podcasthistory.config;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.UUID;
import java.math.BigDecimal;
import java.util.ArrayList;

import com.prmteam7.podcasthistory.model.CreatorSystemBenefit;
import com.prmteam7.podcasthistory.model.CreatorSystemPlan;
import com.prmteam7.podcasthistory.repository.CreatorSystemPlanRepository;

import javax.sql.DataSource;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.stereotype.Component;

@Component
public class DatabaseSeeder implements ApplicationRunner {

    private final JdbcTemplate jdbcTemplate;
    private final DataSource dataSource;
    private final Environment environment;
    private final CreatorSystemPlanRepository creatorSystemPlans;

    public DatabaseSeeder(JdbcTemplate jdbcTemplate, DataSource dataSource, Environment environment,
            CreatorSystemPlanRepository creatorSystemPlans) {
        this.jdbcTemplate = jdbcTemplate;
        this.dataSource = dataSource;
        this.environment = environment;
        this.creatorSystemPlans = creatorSystemPlans;
    }

    @Override
    public void run(ApplicationArguments args) {
        new ResourceDatabasePopulator(
                new ClassPathResource("db/migrations/allow_podcast_drafts_without_media.sql"),
                new ClassPathResource("db/migrations/remove_podcast_slug.sql"))
                .execute(dataSource);

        seedRole("LISTENER", "Listener");
        seedRole("CREATOR", "Creator");
        seedRole("STAFF", "Staff");
        seedRole("ADMIN", "Administrator");

        seedCreatorSystemPlans();

        if (environment.acceptsProfiles(Profiles.of("dev"))) {
            new ResourceDatabasePopulator(
                    new ClassPathResource("db/seeds/development_accounts.sql"))
                    .execute(dataSource);
        }
    }

    private void seedCreatorSystemPlans() {
        if (creatorSystemPlans.count() != 0) return;
        var free = new CreatorSystemPlan();
        free.setCode("FREE");
        free.setName("Free");
        free.setDescription("Gói CC mặc định");
        free.setPrice(BigDecimal.ZERO);
        free.setCurrency("VND");
        free.setDurationDays(null);
        free.setStatus("ACTIVE");
        free.setBenefits(new ArrayList<>(java.util.List.of(
                new CreatorSystemBenefit("UPLOAD_LIMIT", "3", "Tối đa 3 podcast có video/audio"))));
        creatorSystemPlans.save(free);

        var plus = new CreatorSystemPlan();
        plus.setCode("PLUS");
        plus.setName("Plus");
        plus.setDescription("Gói CC trả phí trong 30 ngày");
        plus.setPrice(new BigDecimal("50000.00"));
        plus.setCurrency("VND");
        plus.setDurationDays(30);
        plus.setStatus("ACTIVE");
        plus.setBenefits(new ArrayList<>(java.util.List.of(
                new CreatorSystemBenefit("UPLOAD_LIMIT", "unlimited", "Đăng video/audio không giới hạn"),
                new CreatorSystemBenefit("LIVESTREAM", "true", "Quyền livestream khi tính năng ra mắt"))));
        creatorSystemPlans.save(plus);
    }

    private void seedRole(String code, String name) {
        jdbcTemplate.update("""
                INSERT INTO "Role" (role_id, role_code, role_name, description, created_at)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT (role_code) DO NOTHING
                """,
                UUID.randomUUID(), code, name, "System role", Timestamp.from(Instant.now()));
    }
}
