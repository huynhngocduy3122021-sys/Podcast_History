package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.prmteam7.podcasthistory.dto.request.ContractChatSend;
import com.prmteam7.podcasthistory.exception.PodcastWorkflowException;
import com.prmteam7.podcasthistory.exception.ResourceForbiddenException;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;

@ExtendWith(MockitoExtension.class)
class ContractChatServiceTest {
    @Mock AppUserRepository users;
    @Mock ContractRepository contracts;
    @Mock ContractChatMessageRepository messages;
    @Mock ContractChatRealtimePublisher realtime;
    @InjectMocks ContractChatService service;

    private AppUser listener;
    private AppUser creator;
    private Contract contract;
    private UUID requestId;

    @BeforeEach
    void setup() {
        listener = user("LISTENER");
        creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setUser(listener);
        contract.setProducerProfile(profile);
        contract.setStatus("IN_PROGRESS");
        requestId = UUID.randomUUID();
    }

    @Test
    void listenerCanSendAndCreatorCanReadHistory() {
        UUID clientId = UUID.randomUUID();
        when(users.findById(listener.getUserId())).thenReturn(Optional.of(listener));
        when(users.findById(creator.getUserId())).thenReturn(Optional.of(creator));
        when(contracts.findBySeriesResponse_SeriesRequest_SeriesRequestId(requestId))
                .thenReturn(Optional.of(contract));
        when(contracts.lockById(contract.getContractId())).thenReturn(Optional.of(contract));
        when(messages.saveAndFlush(any(ContractChatMessage.class))).thenAnswer(call -> {
            ContractChatMessage message = call.getArgument(0);
            message.setMessageId(UUID.randomUUID());
            message.setCreatedAt(Instant.now());
            return message;
        });

        var sent = service.send(listener.getUserId(), requestId,
                new ContractChatSend(clientId, "  Tiến độ đợt một thế nào?  "));
        ContractChatMessage stored = new ContractChatMessage();
        stored.setMessageId(sent.messageId());
        stored.setContract(contract);
        stored.setSender(listener);
        stored.setClientMessageId(clientId);
        stored.setContent(sent.content());
        stored.setCreatedAt(sent.createdAt());
        when(messages.findByContract_ContractId(eq(contract.getContractId()), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(stored)));
        var history = service.history(creator.getUserId(), requestId, 0, 20);

        assertEquals("Tiến độ đợt một thế nào?", sent.content());
        assertEquals(sent.messageId(), history.getContent().get(0).messageId());
        verify(realtime).publish(listener.getUserId(), creator.getUserId(), sent);
    }

    @Test
    void unrelatedUserCannotReadOrSend() {
        AppUser outsider = user("LISTENER");
        when(users.findById(outsider.getUserId())).thenReturn(Optional.of(outsider));
        when(contracts.findBySeriesResponse_SeriesRequest_SeriesRequestId(requestId))
                .thenReturn(Optional.of(contract));
        when(contracts.lockById(contract.getContractId())).thenReturn(Optional.of(contract));

        assertThrows(ResourceForbiddenException.class,
                () -> service.history(outsider.getUserId(), requestId, 0, 20));
        assertThrows(ResourceForbiddenException.class,
                () -> service.send(outsider.getUserId(), requestId,
                        new ContractChatSend(UUID.randomUUID(), "Xin chào")));
        verifyNoInteractions(messages, realtime);
    }

    @Test
    void completedContractAllowsReadingButBlocksSending() {
        contract.setStatus("COMPLETED");
        when(users.findById(listener.getUserId())).thenReturn(Optional.of(listener));
        when(contracts.findBySeriesResponse_SeriesRequest_SeriesRequestId(requestId))
                .thenReturn(Optional.of(contract));
        when(contracts.lockById(contract.getContractId())).thenReturn(Optional.of(contract));
        when(messages.findByContract_ContractId(eq(contract.getContractId()), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of()));

        assertTrue(service.history(listener.getUserId(), requestId, 0, 20).isEmpty());
        assertThrows(PodcastWorkflowException.class,
                () -> service.send(listener.getUserId(), requestId,
                        new ContractChatSend(UUID.randomUUID(), "Tin mới")));
        verify(messages, never()).saveAndFlush(any());
    }

    @Test
    void retrySameClientMessageDoesNotCreateOrNotifyTwice() {
        UUID clientId = UUID.randomUUID();
        ContractChatMessage stored = new ContractChatMessage();
        stored.setMessageId(UUID.randomUUID());
        stored.setContract(contract);
        stored.setSender(listener);
        stored.setClientMessageId(clientId);
        stored.setContent("Xin chào");
        stored.setCreatedAt(Instant.now());
        when(users.findById(listener.getUserId())).thenReturn(Optional.of(listener));
        when(contracts.findBySeriesResponse_SeriesRequest_SeriesRequestId(requestId))
                .thenReturn(Optional.of(contract));
        when(contracts.lockById(contract.getContractId())).thenReturn(Optional.of(contract));
        when(messages.findByContract_ContractIdAndSender_UserIdAndClientMessageId(
                contract.getContractId(), listener.getUserId(), clientId)).thenReturn(Optional.of(stored));

        var result = service.send(listener.getUserId(), requestId,
                new ContractChatSend(clientId, "Xin chào"));

        assertEquals(stored.getMessageId(), result.messageId());
        verify(messages, never()).saveAndFlush(any());
        verifyNoInteractions(realtime);
    }

    private AppUser user(String roleCode) {
        Role role = new Role();
        role.setRoleCode(roleCode);
        AppUser user = new AppUser();
        user.setUserId(UUID.randomUUID());
        user.setIsActive(true);
        user.setRole(role);
        return user;
    }
}
