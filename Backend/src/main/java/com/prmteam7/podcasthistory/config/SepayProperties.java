package com.prmteam7.podcasthistory.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "sepay")
public class SepayProperties {

  private String qrBaseUrl = "https://vietqr.app/img";
  private String bankCode = "";
  private String bankAccount = "";
  private String webhookApiKey = "";
  private String codePrefix = "DH";
  private int codeSuffixLength = 14;

  public String getQrBaseUrl() {
    return qrBaseUrl;
  }

  public void setQrBaseUrl(String qrBaseUrl) {
    this.qrBaseUrl = qrBaseUrl;
  }

  public String getBankCode() {
    return bankCode;
  }

  public void setBankCode(String bankCode) {
    this.bankCode = bankCode;
  }

  public String getBankAccount() {
    return bankAccount;
  }

  public void setBankAccount(String bankAccount) {
    this.bankAccount = bankAccount;
  }

  public String getWebhookApiKey() {
    return webhookApiKey;
  }

  public void setWebhookApiKey(String webhookApiKey) {
    this.webhookApiKey = webhookApiKey;
  }

  public String getCodePrefix() {
    return codePrefix;
  }

  public void setCodePrefix(String codePrefix) {
    this.codePrefix = codePrefix;
  }

  public int getCodeSuffixLength() {
    return codeSuffixLength;
  }

  public void setCodeSuffixLength(int codeSuffixLength) {
    this.codeSuffixLength = codeSuffixLength;
  }
}
