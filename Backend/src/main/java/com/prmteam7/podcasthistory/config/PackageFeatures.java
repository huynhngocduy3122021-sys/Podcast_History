package com.prmteam7.podcasthistory.config;

import com.prmteam7.podcasthistory.exception.ResourceConflictException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class PackageFeatures {
  private final boolean creatorPlansEnabled;
  private final boolean membershipsEnabled;

  public PackageFeatures(
      @Value("${features.creator-plans-enabled:false}") boolean creatorPlansEnabled,
      @Value("${features.memberships-enabled:false}") boolean membershipsEnabled) {
    this.creatorPlansEnabled = creatorPlansEnabled;
    this.membershipsEnabled = membershipsEnabled;
  }

  public boolean creatorPlansEnabled() { return creatorPlansEnabled; }

  public boolean membershipsEnabled() { return membershipsEnabled; }

  public void requireCreatorPlans() {
    if (!creatorPlansEnabled) throw new ResourceConflictException("Gói Content Creator đang tạm tắt.");
  }

  public void requireMemberships() {
    if (!membershipsEnabled) throw new ResourceConflictException("Gói membership đang tạm tắt.");
  }
}
