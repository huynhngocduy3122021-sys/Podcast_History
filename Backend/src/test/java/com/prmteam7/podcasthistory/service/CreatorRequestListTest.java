package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.prmteam7.podcasthistory.exception.PodcastWorkflowException;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.math.BigDecimal;
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
class CreatorRequestListTest {
    @Mock AppUserRepository users;
    @Mock ProducerProfileRepository profiles;
    @Mock SeriesRequestRepository requests;
    @Mock ContractEscrowRepository escrows;
    @InjectMocks PodcastRequestService service;

    private AppUser creator;
    private ProducerProfile profile;

    @BeforeEach
    void setup() {
        Role role = new Role();
        role.setRoleCode("CREATOR");
        creator = new AppUser();
        creator.setUserId(UUID.randomUUID());
        creator.setRole(role);
        creator.setIsActive(true);
        profile = new ProducerProfile();
        profile.setProducerProfileId(UUID.randomUUID());
        profile.setUser(creator);
        profile.setChannelName("Kênh lịch sử");
        profile.setAvatarUrl("https://example.test/channel.png");
    }

    @Test
    void allRequestsContainsLegacyAndEscrowOnceEach() {
        SeriesRequest legacy = request("PENDING");
        SeriesRequest funded = request("ACCEPTED");
        Contract contract = new Contract();
        contract.setContractId(UUID.randomUUID());
        contract.setStatus("IN_PROGRESS");
        ContractEscrow escrow = new ContractEscrow();
        escrow.setRequest(funded);
        escrow.setContract(contract);
        escrow.setProductType("AUDIO");
        when(users.findById(creator.getUserId())).thenReturn(Optional.of(creator));
        when(profiles.findByUser_UserId(creator.getUserId())).thenReturn(Optional.of(profile));
        when(requests.findAllByProducerProfile_User_UserId(eq(creator.getUserId()), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(legacy, funded)));
        when(escrows.findAllByRequest_SeriesRequestIdIn(anyCollection())).thenReturn(List.of(escrow));

        var page = service.getCreatorRequests(creator.getUserId(), null, 0, 20);

        assertEquals(2, page.getTotalElements());
        assertEquals("LEGACY", page.getContent().get(0).flowType());
        assertNull(page.getContent().get(0).contractId());
        assertEquals("ESCROW", page.getContent().get(1).flowType());
        assertEquals("IN_PROGRESS", page.getContent().get(1).contractStatus());
        assertEquals(contract.getContractId(), page.getContent().get(1).contractId());
        assertEquals("Người đặt hàng", page.getContent().get(0).listenerName());
        assertEquals("https://example.test/listener.png", page.getContent().get(1).listenerAvatarUrl());
        assertEquals("Kênh lịch sử", page.getContent().get(1).creatorChannelName());
    }

    @Test
    void statusFilterQueriesOnlyCreatorsMatchingRequests() {
        when(users.findById(creator.getUserId())).thenReturn(Optional.of(creator));
        when(profiles.findByUser_UserId(creator.getUserId())).thenReturn(Optional.of(profile));
        when(requests.findAllByProducerProfile_User_UserIdAndStatus(
                eq(creator.getUserId()), eq("REJECTED"), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of()));

        var page = service.getCreatorRequests(creator.getUserId(), "rejected", 0, 20);

        assertTrue(page.isEmpty());
        verifyNoInteractions(escrows);
    }

    @Test
    void incomingRequestIncludesListenerNameAndChannelAvatar() {
        SeriesRequest pending = request("PENDING");
        when(users.findById(creator.getUserId())).thenReturn(Optional.of(creator));
        when(profiles.findByUser_UserId(creator.getUserId())).thenReturn(Optional.of(profile));
        when(requests.findAllByProducerProfile_User_UserIdAndStatusOrderByCreatedAtAsc(
                creator.getUserId(), "PENDING")).thenReturn(List.of(pending));

        var item = service.getCreatorInbox(creator.getUserId()).get(0);

        assertEquals("Người đặt hàng", item.listenerName());
        assertEquals("https://example.test/listener.png", item.listenerAvatarUrl());
        assertEquals("Kênh lịch sử", item.creatorChannelName());
        assertEquals("https://example.test/channel.png", item.creatorAvatarUrl());
    }

    @Test
    void invalidStatusIsRejected() {
        when(users.findById(creator.getUserId())).thenReturn(Optional.of(creator));
        when(profiles.findByUser_UserId(creator.getUserId())).thenReturn(Optional.of(profile));

        assertThrows(PodcastWorkflowException.class,
                () -> service.getCreatorRequests(creator.getUserId(), "UNKNOWN", 0, 20));
        verifyNoInteractions(requests, escrows);
    }

    private SeriesRequest request(String status) {
        AppUser listener = new AppUser();
        listener.setUserId(UUID.randomUUID());
        listener.setDisplayName("Người đặt hàng");
        listener.setAvatarUrl("https://example.test/listener.png");
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setUser(listener);
        request.setProducerProfile(profile);
        request.setRequestedTitle("Lịch sử");
        request.setDescription("Nội dung");
        request.setRequestFee(new BigDecimal("100000"));
        request.setCurrency("VND");
        request.setStatus(status);
        return request;
    }
}
