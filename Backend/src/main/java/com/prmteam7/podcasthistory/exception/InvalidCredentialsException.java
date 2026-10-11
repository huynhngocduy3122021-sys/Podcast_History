package com.prmteam7.podcasthistory.exception;

public class InvalidCredentialsException extends RuntimeException {

    public InvalidCredentialsException() {
        super("Username/email hoặc mật khẩu không đúng, hoặc tài khoản đã bị khóa.");
    }
}
