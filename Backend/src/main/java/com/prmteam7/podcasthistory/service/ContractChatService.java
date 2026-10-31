package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.dto.request.ContractChatSend;
import com.prmteam7.podcasthistory.dto.response.ContractChatItem;
import com.prmteam7.podcasthistory.exception.PodcastWorkflowException;
import com.prmteam7.podcasthistory.exception.PodcastWorkflowNotFoundException;
import com.prmteam7.podcasthistory.exception.ResourceForbiddenException;
import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.Contract;
import com.prmteam7.podcasthistory.model.ContractChatMessage;
import com.prmteam7.podcasthistory.repository.AppUserRepository;
import com.prmteam7.podcasthistory.repository.ContractChatMessageRepository;
import com.prmteam7.podcasthistory.repository.ContractRepository;
import java.util.Set;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ContractChatService {
    private static final Set<String> OPEN_STATUSES = Set.of("PENDING_SIGNATURE", "IN_PROGRESS", "DISPUTED");
    private final AppUserRepository users;
    private final ContractRepository contracts;
    private final ContractChatMessageRepository messages;
    private final ContractChatRealtimePublisher realtime;

    public ContractChatService(AppUserRepository users, ContractRepository contracts,
            ContractChatMessageRepository messages, ContractChatRealtimePublisher realtime) {
        this.users = users;
        this.contracts = contracts;
        this.messages = messages;
        this.realtime = realtime;
    }

    @Transactional(readOnly = true)
    public Page<ContractChatItem> history(UUID actorId, UUID requestId, int page, int size) {
        AppUser actor = activeUser(actorId);
        Contract contract = contractForRequest(requestId);
        requireParticipant(contract, actor);
        return messages.findByContract_ContractId(contract.getContractId(),
                PageRequest.of(Math.max(0, page), Math.min(100, Math.max(1, size)),
                        Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("messageId"))))
                .map(message -> item(requestId, message));
    }

    @Transactional
    public ContractChatItem send(UUID actorId, UUID requestId, ContractChatSend input) {
        AppUser actor = activeUser(actorId);
        Contract snapshot = contractForRequest(requestId);
        Contract contract = contracts.lockById(snapshot.getContractId())
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy hợp đồng."));
        requireParticipant(contract, actor);
        if (!OPEN_STATUSES.contains(contract.getStatus()))
            throw new PodcastWorkflowException("Hợp đồng đã đóng; chỉ được xem lịch sử chat.");
        String content = input.content().trim();
        if (content.isEmpty() || content.length() > 2000)
            throw new PodcastWorkflowException("Tin nhắn phải có từ 1 đến 2000 ký tự.");
        var existing = messages.findByContract_ContractIdAndSender_UserIdAndClientMessageId(
                contract.getContractId(), actorId, input.clientMessageId());
        if (existing.isPresent()) {
            if (!existing.get().getContent().equals(content))
                throw new PodcastWorkflowException("Mã tin nhắn đã được dùng cho nội dung khác.");
            return item(requestId, existing.get());
        }
        ContractChatMessage message = new ContractChatMessage();
        message.setContract(contract);
        message.setSender(actor);
        message.setClientMessageId(input.clientMessageId());
        message.setContent(content);
        ContractChatItem saved = item(requestId, messages.saveAndFlush(message));
        realtime.publish(contract.getUser().getUserId(),
                contract.getProducerProfile().getUser().getUserId(), saved);
        return saved;
    }

    private Contract contractForRequest(UUID requestId) {
        return contracts.findBySeriesResponse_SeriesRequest_SeriesRequestId(requestId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("CC chưa tạo hợp đồng cho yêu cầu này."));
    }

    private AppUser activeUser(UUID actorId) {
        AppUser actor = users.findById(actorId)
                .orElseThrow(() -> new PodcastWorkflowNotFoundException("Không tìm thấy tài khoản."));
        if (!Boolean.TRUE.equals(actor.getIsActive()))
            throw new PodcastWorkflowException("Tài khoản không hoạt động.");
        return actor;
    }

    private void requireParticipant(Contract contract, AppUser actor) {
        UUID id = actor.getUserId();
        String role = actor.getRole() == null ? "" : actor.getRole().getRoleCode();
        boolean listener = id.equals(contract.getUser().getUserId()) && "LISTENER".equalsIgnoreCase(role);
        boolean creator = id.equals(contract.getProducerProfile().getUser().getUserId())
                && "CREATOR".equalsIgnoreCase(role);
        if (!listener && !creator)
            throw new ResourceForbiddenException("Chỉ Listener và CC của hợp đồng được chat.");
    }

    private ContractChatItem item(UUID requestId, ContractChatMessage message) {
        return new ContractChatItem(message.getMessageId(), requestId,
                message.getContract().getContractId(), message.getSender().getUserId(),
                message.getClientMessageId(), message.getContent(), message.getCreatedAt());
    }
}
