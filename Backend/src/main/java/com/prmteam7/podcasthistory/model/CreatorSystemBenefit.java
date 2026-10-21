package com.prmteam7.podcasthistory.model;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;

@Embeddable
public class CreatorSystemBenefit {
  @Column(name = "benefit_key", nullable = false, length = 60)
  private String key;

  @Column(name = "benefit_value", nullable = false, length = 200)
  private String value;

  @Column(name = "description", length = 500)
  private String description;

  public CreatorSystemBenefit() {}

  public CreatorSystemBenefit(String key, String value, String description) {
    this.key = key;
    this.value = value;
    this.description = description;
  }

  public String getKey() { return key; }
  public void setKey(String key) { this.key = key; }
  public String getValue() { return value; }
  public void setValue(String value) { this.value = value; }
  public String getDescription() { return description; }
  public void setDescription(String description) { this.description = description; }
}
