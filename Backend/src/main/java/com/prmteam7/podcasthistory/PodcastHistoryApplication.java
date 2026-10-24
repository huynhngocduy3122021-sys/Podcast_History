package com.prmteam7.podcasthistory;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;

@SpringBootApplication
@EnableAsync
public class PodcastHistoryApplication {

    public static void main(String[] args) {
        SpringApplication.run(PodcastHistoryApplication.class, args);
    }
}
