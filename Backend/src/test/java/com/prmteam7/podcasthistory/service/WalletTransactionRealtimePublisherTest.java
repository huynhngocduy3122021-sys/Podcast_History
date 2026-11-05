package com.prmteam7.podcasthistory.service;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

import com.prmteam7.podcasthistory.model.AppUser;
import com.prmteam7.podcasthistory.model.UserWallet;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationEventPublisher;

class WalletTransactionRealtimePublisherTest {
  @Test
  void sendsWalletRefreshOnlyToItsOwner() {
    ApplicationEventPublisher events = mock(ApplicationEventPublisher.class);
    RealtimeEventPublisher realtime = mock(RealtimeEventPublisher.class);
    WalletTransactionRealtimePublisher publisher =
        new WalletTransactionRealtimePublisher(events, realtime);
    UUID userId = UUID.randomUUID();
    UUID walletId = UUID.randomUUID();
    AppUser owner = new AppUser();
    owner.setUserId(userId);
    UserWallet wallet = new UserWallet();
    wallet.setUserWalletId(walletId);
    wallet.setUser(owner);

    publisher.changed(wallet);

    var event = new WalletTransactionRealtimePublisher.WalletChanged(userId, walletId);
    verify(events).publishEvent(event);
    publisher.send(event);
    verify(realtime).publishUser(eq(userId), eq("WALLET_TRANSACTIONS_CHANGED"),
        eq(Map.of("walletId", walletId)));
    verifyNoMoreInteractions(realtime);
  }
}
