package com.prmteam7.podcasthistory.exception;

public class InvalidRefreshTokenException extends RuntimeException {

    public InvalidRefreshTokenException() {
        super("Refresh token không hợp lệ, đã hết hạn hoặc đã được sử dụng.");
    }
}
