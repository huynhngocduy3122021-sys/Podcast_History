package com.prmteam7.podcasthistory.exception;

public class R2UploadException extends RuntimeException {

    public R2UploadException(Throwable cause) {
        super("Không thể tải media lên Cloudflare R2.", cause);
    }
}
