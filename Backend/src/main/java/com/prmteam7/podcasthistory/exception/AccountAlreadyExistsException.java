package com.prmteam7.podcasthistory.exception;

public class AccountAlreadyExistsException extends RuntimeException {

    public AccountAlreadyExistsException() {
        super("Username hoặc email đã được sử dụng.");
    }
}
