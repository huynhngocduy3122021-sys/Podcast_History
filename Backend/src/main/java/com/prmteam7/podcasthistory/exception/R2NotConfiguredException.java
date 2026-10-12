package com.prmteam7.podcasthistory.exception;

public class R2NotConfiguredException extends RuntimeException {

    public R2NotConfiguredException() {
        super("Cloudflare R2 chưa được cấu hình đầy đủ trong file Backend/.env.");
    }
}
