package com.prmteam7.podcasthistory.enums;

public enum PodcastVisibility {
    PUBLIC, MEMBERS_ONLY;

    public boolean isExclusive() {
        return this == MEMBERS_ONLY;
    }

    public static PodcastVisibility fromExclusive(Boolean exclusive) {
        return Boolean.TRUE.equals(exclusive) ? MEMBERS_ONLY : PUBLIC;
    }
}
