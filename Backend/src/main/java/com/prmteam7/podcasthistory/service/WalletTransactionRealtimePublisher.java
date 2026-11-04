package com.prmteam7.podcasthistory.service;

import com.prmteam7.podcasthistory.model.UserWallet;
import java.util.Map;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/** Refresh signal for the owner of a wallet after its transaction history commits. */
@Component
public class WalletTransactionRealtimePublisher {
  private final ApplicationEventPublisher events;
  private final RealtimeEventPublisher realtime;

  public WalletTransactionRealtimePublisher(ApplicationEventPublisher events,
      RealtimeEventPublisher realtime) {
    this.events = events;
    this.realtime = realtime;
  }

  public void changed(UserWallet wallet) {
    if (wallet == null || wallet.getUser() == null || wallet.getUser().getUserId() == null) return;
    events.publishEvent(new WalletChanged(wallet.getUser().getUserId(), wallet.getUserWalletId()));
  }

  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
  public void send(WalletChanged event) {
    realtime.publishUser(event.userId(), "WALLET_TRANSACTIONS_CHANGED",
        Map.of("walletId", event.walletId()));
  }

  public record WalletChanged(UUID userId, UUID walletId) {}
}
