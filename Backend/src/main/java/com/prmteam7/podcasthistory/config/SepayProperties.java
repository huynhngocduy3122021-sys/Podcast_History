package com.prmteam7.podcasthistory.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "sepay")
public class SepayProperties {
  private String webhookApiKey = "";
  private String accountNumber = "";
  private String bank = "";
  private String paymentCodePrefix = "MEM";

  public String getWebhookApiKey() {
    return webhookApiKey;
  }

  public void setWebhookApiKey(String webhookApiKey) {
    this.webhookApiKey = webhookApiKey;
  }

  public String getAccountNumber() {
    return accountNumber;
  }

  public void setAccountNumber(String accountNumber) {
    this.accountNumber = accountNumber;
  }

  public String getBank() {
    return bank;
  }

  public void setBank(String bank) {
    this.bank = bank;
  }

  public String getPaymentCodePrefix() {
    return paymentCodePrefix;
  }

  public void setPaymentCodePrefix(String paymentCodePrefix) {
    this.paymentCodePrefix = paymentCodePrefix;
  }

  public boolean isQrConfigured() {
    return hasText(accountNumber) && hasText(bank) && hasText(paymentCodePrefix);
  }

  private boolean hasText(String value) {
    return value != null && !value.isBlank();
  }
}
