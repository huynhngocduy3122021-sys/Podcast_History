# Cài Agora cho Flutter và nối luồng livestream

Tài liệu này dành cho frontend tích hợp live của **Content Creator (host)** và **Listener (audience)**. SDK đã được cài trong project; hiện **chưa có màn hình, lời gọi API hoặc mã tham gia phòng Agora** trong `Frontend/lib`.

## 1. Những gì đã cài sẵn

- `Frontend/pubspec.yaml`: `agora_rtc_engine: ^6.6.4` và `permission_handler: ^12.0.3`. `pubspec.lock` đã được cập nhật bằng `flutter pub get`.
- Android: quyền `INTERNET`, `CAMERA`, `RECORD_AUDIO` trong `android/app/src/main/AndroidManifest.xml`; compile SDK 35 cho plugin Agora trong `android/build.gradle.kts`.
- iOS: `NSCameraUsageDescription` và `NSMicrophoneUsageDescription` trong `ios/Runner/Info.plist`.
- Web: `web/index.html` nạp `web/iris-web-rtc_n450_w4220_0.8.6.js` trước Flutter. Đây là runtime web được [README của Agora Flutter SDK](https://pub.dev/packages/agora_rtc_engine) yêu cầu; không cần tự thêm URL CDN.

Trong thư mục `Frontend`, chạy `flutter pub get` sau khi pull code. Không điền App ID hoặc App Certificate vào frontend. Backend đọc hai giá trị từ `Backend/.env` và trả App ID cùng token qua API.

## 2. API và dữ liệu Content Creator cần dùng

Mỗi request gửi `Authorization: Bearer <accessToken>` của tài khoản role `CREATOR`, có kênh đã duyệt.

| Thứ tự | API | Body / dữ liệu nhập | Kết quả cần dùng |
| --- | --- | --- | --- |
| 1 | `POST /api/creator/livestreams` | JSON `title` bắt buộc, tối đa 220 ký tự; `description` tùy chọn, tối đa 10000 ký tự; `scheduledAt` tùy chọn dạng ISO-8601 UTC hoặc `null` | Lưu `livestreamId`, trạng thái `DRAFT` |
| 2 | `POST /api/creator/livestreams/{livestreamId}/start` | Không có body | Trạng thái chuyển `LIVE`; nhận `appId`, `channelName`, `userAccount`, `token`, `expiresAt` |
| 3 | `POST /api/creator/livestreams/{livestreamId}/token` | Không có body; gọi khi token gần hết hạn | Token host mới để gọi `renewToken` của Agora SDK |
| 4 | `POST /api/creator/livestreams/{livestreamId}/end` | Không có body | Trạng thái `ENDED`; frontend rời kênh và giải phóng engine |

Ví dụ body bước 1:

```json
{
  "title": "Giao lưu lịch sử tối nay",
  "description": "Hỏi đáp trực tiếp cùng người nghe",
  "scheduledAt": null
}
```

`GET /api/creator/livestreams` trả các live của chính kênh CC, gồm cả `DRAFT`, `LIVE`, `ENDED`. `GET /api/creator/livestreams/{livestreamId}` lấy chi tiết. Nếu gọi lại `/start` trên cùng phiên `LIVE`, backend cấp token host mới để có thể kết nối lại; một kênh chỉ có một phiên `LIVE` cùng lúc.

Sau bước 2, frontend phải xin quyền camera/micro trên Android/iOS, khởi tạo `RtcEngine` với `appId`, chọn `channelProfileLiveBroadcasting`, `clientRoleBroadcaster`, bật camera/micro, rồi dùng **`joinChannelWithUserAccount`** với đúng `token`, `channelName`, `userAccount` từ response. Token backend được tạo theo *user account*; không đổi sang phương thức join bằng UID số. Khi kết thúc, gọi API `/end` và `leaveChannel`/`release` của SDK.

## 3. API và dữ liệu Listener cần dùng

Mỗi request gửi JWT role `LISTENER`.

| Thứ tự | API | Body / tham số | Kết quả cần dùng |
| --- | --- | --- | --- |
| 1 | `GET /api/livestreams?page=0&size=20` | `page` bắt đầu từ 0; `size` tùy chọn | `content[]` gồm các phiên đang `LIVE` của kênh đã duyệt |
| 2 | `GET /api/livestreams/{livestreamId}` | Không có body | Chi tiết phiên đang phát |
| 3 | `POST /api/livestreams/{livestreamId}/join` | Không có body | `appId`, `channelName`, `userAccount`, `token`, `expiresAt` với `role: audience` |

Listener dùng `joinChannelWithUserAccount`, `channelProfileLiveBroadcasting`, `clientRoleAudience`, chỉ subscribe audio/video; **không publish camera/micro**. Khi token gần hết hạn, gọi lại API `/join` rồi đưa token mới vào `renewToken`. Khi rời màn hình, gọi `leaveChannel`/`release`; không gọi API `/end` của CC.

## 4. Response token và trạng thái cần hiểu

Response của `/start`, `/token` và `/join` có dạng:

```json
{
  "livestreamId": "UUID",
  "appId": "App ID Agora",
  "channelName": "live_<mã kênh>",
  "userAccount": "UUID tài khoản đăng nhập",
  "role": "host hoặc audience",
  "token": "Agora RTC token",
  "expiresAt": "2026-10-25T12:00:00Z"
}
```

API `/start` chỉ đổi trạng thái trong database và cấp token. **Hình/âm thanh chỉ có sau khi host thực sự join và publish qua Agora SDK**. Vì vậy `HTTP 200` từ `/start` chưa chứng minh camera đang phát. Backend hiện chưa có API xác nhận host đã vào kênh; listener có thể thấy phiên `LIVE` nhưng màn hình chờ hình nếu host chưa join.

Token mặc định sống 3600 giây. Dùng callback `onTokenPrivilegeWillExpire` của Agora để gọi API gia hạn đúng role và sau đó gọi `renewToken`. Không ghi token hoặc App Certificate vào log. App Certificate chỉ lưu ở backend.

## 5. Chạy và kiểm tra

1. Đảm bảo backend đang chạy và `Backend/.env` có `AGORA_APP_ID`, `AGORA_APP_CERTIFICATE` cùng một project Agora bật **App ID + Token**.
2. Chạy `flutter pub get` trong `Frontend`. Khi chạy web, dùng `localhost` hoặc HTTPS để trình duyệt cho phép camera/micro. Nếu đổi backend URL, cập nhật cấu hình API của cả luồng Listener và Creator.
3. Đăng nhập CC, tạo draft, gọi `/start`, rồi cho host join và publish. Đăng nhập Listener trên trình duyệt/thiết bị khác, gọi `/api/livestreams` rồi `/join` để subscribe.
4. Kiểm tra hình và âm thanh trên hai thiết bị, gia hạn token, kết thúc live và xác nhận phiên biến mất khỏi danh sách Listener.

Đã build thành công Android debug và web với SDK đã cài. Chưa xác nhận một phiên Agora thực tế giữa hai tài khoản. [Agora ghi hỗ trợ web của Flutter plugin vẫn ở giai đoạn alpha](https://pub.dev/packages/agora_rtc_engine), nên cần kiểm tra trên trình duyệt mục tiêu trước khi phát hành.
