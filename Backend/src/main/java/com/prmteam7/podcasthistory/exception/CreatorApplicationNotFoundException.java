package com.prmteam7.podcasthistory.exception;

public class CreatorApplicationNotFoundException extends RuntimeException {

    public CreatorApplicationNotFoundException() {
        super("Không tìm thấy hồ sơ đăng ký Creator.");
    }
}
