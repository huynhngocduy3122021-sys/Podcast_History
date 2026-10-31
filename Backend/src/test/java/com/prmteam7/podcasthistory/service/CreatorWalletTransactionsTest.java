package com.prmteam7.podcasthistory.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.prmteam7.podcasthistory.exception.WalletWorkflowException;
import com.prmteam7.podcasthistory.model.*;
import com.prmteam7.podcasthistory.repository.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;

@ExtendWith(MockitoExtension.class)
class CreatorWalletTransactionsTest {
    @Mock AppUserRepository users;
    @Mock ProducerProfileRepository creators;
    @Mock UserWalletRepository wallets;
    @Mock CreatorPayoutAccountRepository payoutAccounts;
    @Mock WithdrawalRequestRepository withdrawals;
    @Mock WalletTransactionRepository transactions;
    @Mock PayoutPaymentRepository payments;
    @InjectMocks CreatorWalletService service;

    @Test
    void creatorSeesOwnContractCreditWithPaginationAndStatusFilter() {
        AppUser creator = user("CREATOR");
        ProducerProfile profile = new ProducerProfile();
        profile.setUser(creator);
        WalletTransaction credit = new WalletTransaction();
        credit.setWalletTransactionId(UUID.randomUUID());
        credit.setTransactionType("RELEASE_FUNDS");
        credit.setDirection("CREDIT");
        credit.setAmount(new BigDecimal("24000.00"));
        credit.setCurrency("VND");
        credit.setStatus("COMPLETED");
        credit.setReferenceCode("CONTRACT_CREATOR:stage-id");
        credit.setBalanceAfter(new BigDecimal("24000.00"));
        credit.setHeldBalanceAfter(BigDecimal.ZERO);
        credit.setCreatedAt(Instant.now());
        when(users.findById(creator.getUserId())).thenReturn(Optional.of(creator));
        when(creators.findByUser_UserId(creator.getUserId())).thenReturn(Optional.of(profile));
        when(transactions.findForUser(eq(creator.getUserId()), eq("COMPLETED"), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(credit)));

        var result = service.transactions(creator.getUserId(), " COMPLETED ", 0, 20);

        assertEquals(1, result.getTotalElements());
        assertEquals("RELEASE_FUNDS", result.getContent().get(0).type());
        assertEquals(new BigDecimal("24000.00"), result.getContent().get(0).amount());
        verify(transactions).findForUser(eq(creator.getUserId()), eq("COMPLETED"),
                argThat(pageable -> pageable.getPageNumber() == 0
                        && pageable.getPageSize() == 20
                        && pageable.getSort().getOrderFor("createdAt") != null));
    }

    @Test
    void listenerCannotReadCreatorTransactionEndpoint() {
        AppUser listener = user("LISTENER");
        when(users.findById(listener.getUserId())).thenReturn(Optional.of(listener));

        assertThrows(WalletWorkflowException.class,
                () -> service.transactions(listener.getUserId(), null, 0, 20));

        verifyNoInteractions(transactions);
    }

    private AppUser user(String roleCode) {
        Role role = new Role();
        role.setRoleCode(roleCode);
        AppUser user = new AppUser();
        user.setUserId(UUID.randomUUID());
        user.setRole(role);
        user.setIsActive(true);
        return user;
    }
}
