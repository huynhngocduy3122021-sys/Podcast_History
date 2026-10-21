package com.prmteam7.podcasthistory.config;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.UUID;

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

    public DatabaseSeeder(JdbcTemplate jdbcTemplate, DataSource dataSource, Environment environment) {
        this.jdbcTemplate = jdbcTemplate;
        this.dataSource = dataSource;
        this.environment = environment;
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

        if (environment.acceptsProfiles(Profiles.of("dev"))) {
            new ResourceDatabasePopulator(
                    new ClassPathResource("db/seeds/development_accounts.sql"))
                    .execute(dataSource);
        }
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
