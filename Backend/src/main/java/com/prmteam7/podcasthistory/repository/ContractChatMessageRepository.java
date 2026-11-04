package com.prmteam7.podcasthistory.repository;

import com.prmteam7.podcasthistory.model.ContractChatMessage;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ContractChatMessageRepository extends JpaRepository<ContractChatMessage, UUID> {
    Page<ContractChatMessage> findByContract_ContractId(UUID contractId, Pageable pageable);
    Optional<ContractChatMessage> findByContract_ContractIdAndSender_UserIdAndClientMessageId(
            UUID contractId, UUID senderId, UUID clientMessageId);
}
