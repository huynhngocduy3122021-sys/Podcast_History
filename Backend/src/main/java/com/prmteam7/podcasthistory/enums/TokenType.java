package com.prmteam7.podcasthistory.enums;

/** Token type written to the JWT claim. Refresh tokens are opaque values, not JWTs. */
public enum TokenType {
    ACCESS("access");

    private final String claimValue;

    TokenType(String claimValue) {
        this.claimValue = claimValue;
    }

    public String claimValue() {
        return claimValue;
    }
}
