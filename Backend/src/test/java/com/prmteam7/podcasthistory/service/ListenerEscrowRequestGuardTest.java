package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;

import com.prmteam7.podcasthistory.dto.request.ListenerRequests.SeriesRequestUpdate;
import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.SeriesRequest;
import com.prmteam7.podcasthistory.repository.SeriesRequestRepository;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ListenerEscrowRequestGuardTest {
    @Mock SeriesRequestRepository requests;
    @Mock ContractEscrowService escrows;
    @InjectMocks ListenerFlowService service;

    @Test
    void legacyEditCannotChangeHeldRequestBeforeCreatorProposal() {
        UUID listenerId = UUID.randomUUID();
        SeriesRequest request = pendingRequest(listenerId);
        when(requests.findByIdForUpdate(request.getSeriesRequestId())).thenReturn(Optional.of(request));
        when(escrows.isEscrowRequest(request.getSeriesRequestId())).thenReturn(true);

        assertThrows(ResourceConflictException.class, () -> service.updateSeriesRequest(
                listenerId, request.getSeriesRequestId(),
                new SeriesRequestUpdate("Tên đã đổi", "Mô tả đã đổi")));

        verify(requests, never()).save(request);
        verify(requests, never()).findById(request.getSeriesRequestId());
    }

    @Test
    void legacyCancelDelegatesEscrowRefundUnderRequestLock() {
        UUID listenerId = UUID.randomUUID();
        SeriesRequest request = pendingRequest(listenerId);
        when(requests.findByIdForUpdate(request.getSeriesRequestId())).thenReturn(Optional.of(request));
        when(escrows.isEscrowRequest(request.getSeriesRequestId())).thenReturn(true);

        service.cancelSeriesRequest(listenerId, request.getSeriesRequestId());

        verify(escrows).cancel(listenerId, request.getSeriesRequestId());
        verify(requests, never()).save(request);
    }

    private SeriesRequest pendingRequest(UUID listenerId) {
        AppUser listener = new AppUser();
        listener.setUserId(listenerId);
        SeriesRequest request = new SeriesRequest();
        request.setSeriesRequestId(UUID.randomUUID());
        request.setUser(listener);
        request.setStatus("PENDING");
        return request;
    }
}
