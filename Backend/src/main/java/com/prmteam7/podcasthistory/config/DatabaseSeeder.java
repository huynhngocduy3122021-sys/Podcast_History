package com.prmteam7.podcasthistory.config;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.UUID;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
public class DatabaseSeeder implements ApplicationRunner {

    private final JdbcTemplate jdbcTemplate;

    public DatabaseSeeder(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void run(ApplicationArguments args) {
        seedRole("LISTENER", "Listener");
        seedRole("CREATOR", "Creator");
        seedRole("ADMIN", "Administrator");
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
