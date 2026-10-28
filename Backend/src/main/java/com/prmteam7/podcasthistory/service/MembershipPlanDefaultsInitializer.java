package com.prmteam7.podcasthistory.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

/** Ensures existing approved channels receive the single membership template after deployment. */
@Component
public class MembershipPlanDefaultsInitializer implements ApplicationRunner {
  private static final Logger log = LoggerFactory.getLogger(MembershipPlanDefaultsInitializer.class);

  private final MembershipPlanDefaultsService defaults;

  public MembershipPlanDefaultsInitializer(MembershipPlanDefaultsService defaults) {
    this.defaults = defaults;
  }

  @Override
  public void run(ApplicationArguments args) {
    int created = defaults.provisionApprovedChannels();
    log.info("Membership plan defaults provisioned: {} plan(s)", created);
  }
}
