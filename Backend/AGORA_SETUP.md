# Agora livestream (backend)

## Cấu hình

Trong Agora Console, chọn project dùng chế độ **App ID + Token**. Sao chép App ID và App Certificate vào `Backend/.env` (file này được Git bỏ qua):

```properties
AGORA_APP_ID=<32 ký tự hex>
AGORA_APP_CERTIFICATE=<32 ký tự hex>
AGORA_TOKEN_TTL_SECONDS=3600
```

Chạy backend từ thư mục `Backend` bằng `mvn spring-boot:run`. Backend cũng đọc `Backend/.env` khi chạy từ thư mục gốc. Khởi động lại sau khi đổi khóa. App Certificate chỉ giữ trên server; không gửi cho frontend. Nếu thiếu cấu hình, API cấp token trả HTTP 503.

## Luồng Content Creator

Tất cả API dưới đây cần JWT role `CREATOR` và kênh đã được duyệt, còn hoạt động.

1. `POST /api/creator/livestreams` với JSON `{"title":"Tên buổi live","description":"Mô tả tùy chọn","scheduledAt":null}`. `title` bắt buộc, tối đa 220 ký tự; `description` tùy chọn, tối đa 10000 ký tự; `scheduledAt` tùy chọn, là ISO-8601 UTC. Trả HTTP 201 cùng metadata có `livestreamId`, `status: DRAFT`.
2. `POST /api/creator/livestreams/{livestreamId}/start` (không có body). Chuyển sang `LIVE`, trả `appId`, `channelName`, `userAccount`, `role: host`, `token`, `expiresAt`. Gọi lại trên cùng buổi `LIVE` sẽ cấp token mới.
3. Dùng đúng `token`, `channelName`, `userAccount` để host vào Agora SDK và phát camera/micro. Khi token gần hết hạn, gọi `POST /api/creator/livestreams/{livestreamId}/token` rồi renew trong SDK.
4. `POST /api/creator/livestreams/{livestreamId}/end` (không có body). Chuyển sang `ENDED`; host cũng cần rời kênh Agora.

`GET /api/creator/livestreams` trả danh sách của kênh; `GET /api/creator/livestreams/{livestreamId}` trả chi tiết. Mỗi kênh chỉ có một phiên `LIVE` cùng lúc.

## Luồng Listener

Các API này cần JWT role `LISTENER`, tài khoản hoạt động.

1. `GET /api/livestreams?page=0&size=20` trả trang các buổi `LIVE` của kênh đã duyệt.
2. `GET /api/livestreams/{livestreamId}` trả metadata một buổi đang phát.
3. `POST /api/livestreams/{livestreamId}/join` (không có body) trả `appId`, `channelName`, `userAccount`, `role: audience`, `token`, `expiresAt`. Listener vào Agora SDK bằng các trường này và chỉ subscribe. Gọi lại API để lấy token mới khi gần hết hạn.

Backend không phát video qua HTTP và không lưu bản ghi. Token audience không được cấp sau khi phiên đã `ENDED`; token đã cấp trước đó còn hiệu lực tới `expiresAt` theo Agora. Nếu cần ngắt tức thì người xem hoặc xác nhận host đã vào kênh, phải bổ sung cơ chế Agora tương ứng.

## Chat trong livestream

Bật **Signaling** trong cùng Agora project. Creator gọi `POST /api/creator/livestreams/{livestreamId}/chat-token`, Listener gọi `POST /api/livestreams/{livestreamId}/chat-token` khi phiên đang `LIVE`. Response gồm `appId`, `channelName`, `userId`, `displayName`, `token`, `expiresAt`; đây là **RTM token**, tách với RTC token của `/start` và `/join`. Frontend login/subscribe/publish trực tiếp qua Agora Signaling. Backend không lưu tin nhắn. Xem `docs/content-creator/AGORA_LIVE_CHAT.md`.
