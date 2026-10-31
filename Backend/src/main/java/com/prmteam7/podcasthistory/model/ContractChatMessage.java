package com.prmteam7.podcasthistory.model;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "contract_chat_message", uniqueConstraints = {
        @UniqueConstraint(name = "uk_contract_chat_client_message", columnNames = {
                "contract_id", "sender_user_id", "client_message_id"})
}, indexes = {
        @Index(name = "idx_contract_chat_history", columnList = "contract_id, created_at")
})
public class ContractChatMessage extends BaseEntity {
    @Id
    @Column(name = "message_id", nullable = false, updatable = false)
    private UUID messageId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "contract_id", nullable = false)
    private Contract contract;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "sender_user_id", nullable = false)
    private AppUser sender;

    @Column(name = "client_message_id", nullable = false, updatable = false)
    private UUID clientMessageId;

    @Column(name = "content", nullable = false, columnDefinition = "text")
    private String content;

    @PrePersist
    private void assignId() {
        if (messageId == null) messageId = UUID.randomUUID();
    }

    public UUID getMessageId() { return messageId; }
    public void setMessageId(UUID value) { messageId = value; }
    public Contract getContract() { return contract; }
    public void setContract(Contract value) { contract = value; }
    public AppUser getSender() { return sender; }
    public void setSender(AppUser value) { sender = value; }
    public UUID getClientMessageId() { return clientMessageId; }
    public void setClientMessageId(UUID value) { clientMessageId = value; }
    public String getContent() { return content; }
    public void setContent(String value) { content = value; }
}
