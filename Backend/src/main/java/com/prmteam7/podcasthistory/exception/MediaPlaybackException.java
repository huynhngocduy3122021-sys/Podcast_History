package com.prmteam7.podcasthistory.exception;

public class MediaPlaybackException extends RuntimeException {

    public MediaPlaybackException(Throwable cause) {
        super("Không thể tạo URL phát media. Hãy kiểm tra cấu hình và quyền truy cập Cloudflare R2.", cause);
    }
}
