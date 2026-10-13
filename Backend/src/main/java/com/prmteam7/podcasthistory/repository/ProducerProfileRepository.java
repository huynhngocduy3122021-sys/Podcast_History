package com.prmteam7.podcasthistory.repository;

import java.util.UUID;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.prmteam7.podcasthistory.model.ProducerProfile;

public interface ProducerProfileRepository extends JpaRepository<ProducerProfile, UUID> {

    boolean existsByChannelNameIgnoreCase(String channelName);

    boolean existsByUser_UserId(UUID userId);

    Optional<ProducerProfile> findByUser_UserId(UUID userId);
}
