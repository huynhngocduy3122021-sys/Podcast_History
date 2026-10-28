# Chat trực tiếp trong livestream qua Agora Signaling

Chat dùng **Agora Signaling (RTM) 2.x**. Backend chỉ xác thực quyền xem/phát và cấp token. Tin nhắn được publish/subscribe trực tiếp qua Agora, **không lưu vào database của ứng dụng**; người vào sau vẫn không có lịch sử chat của những người khác. Ứng dụng lưu cục bộ tối đa 100 tin nhắn theo từng livestream, nên đóng/mở lại khung chat hoặc vào lại màn hình vẫn giữ được lịch sử đã nhận trên thiết bị đó.

## Cấu hình

Trong Agora Console, bật **Signaling** cho cùng project `AGORA_APP_ID` / `AGORA_APP_CERTIFICATE` đang dùng cho RTC. Giữ App Certificate trong `Backend/.env`, không đưa lên frontend. Sau khi cập nhật backend, khởi động lại server.

Frontend dùng `agora_rtm 2.2.5` cho Android/iOS. Flutter Web dùng bản Agora Signaling Web SDK được đóng gói ở `Frontend/web/agora-rtm-bundle.js` và bridge `agora_chat_bridge.js`; hai script được nạp từ `web/index.html`. Sau khi pull code, chạy `flutter pub get`.

## Thứ tự gọi

1. Creator gọi `POST /api/creator/livestreams/{livestreamId}/start` như luồng live hiện tại. Listener gọi `POST /api/livestreams/{livestreamId}/join`. Đây là token **RTC** cho âm thanh và hình ảnh.
2. Khi màn hình live mở, gọi một trong hai API dưới đây với `Authorization: Bearer <accessToken>`. Không có request body:

   | Vai trò | API chat |
   | --- | --- |
   | Creator chủ phiên | `POST /api/creator/livestreams/{livestreamId}/chat-token` |
   | Listener | `POST /api/livestreams/{livestreamId}/chat-token` |

3. Dùng response chat để `login` Agora Signaling bằng `appId`, `userId`, `token`, sau đó `subscribe` vào `channelName` dạng message channel. Hai bên dùng cùng `channelName` nhưng có `userId` riêng.
4. Khi gửi, publish JSON `{"name":"Tên hiển thị","text":"Nội dung"}` vào message channel. UI giới hạn 300 ký tự và chỉ giữ tối đa 100 tin gần nhất trong bộ nhớ. Khi nhận, hiển thị `publisher`, tên và nội dung. Tin nhắn **không đi qua API backend**.
5. Trước `expiresAt` khoảng 2 phút, gọi lại đúng API chat token của vai trò rồi `renewToken`. Khi rời màn hình, `unsubscribe` và `logout` Agora Signaling. Creator kết thúc live bằng API `/end` của RTC như trước.

Response của API chat token:

```json
{
  "livestreamId": "UUID",
  "appId": "Agora App ID",
  "channelName": "chat_live_<mã phiên>",
  "userId": "ID Agora Signaling của tài khoản",
  "displayName": "Tên hiển thị",
  "token": "Agora Signaling token",
  "expiresAt": "2026-10-26T10:00:00Z"
}
```

API chỉ cấp token khi phiên ở trạng thái `LIVE`. Creator phải là chủ kênh được duyệt; Listener phải là tài khoản hoạt động và phiên live phải hiển thị được. Token Signaling khác token RTC, không dùng lẫn. Không ghi token vào log.

Agora Signaling message channel không lưu lịch sử theo cấu hình này. Token đã cấp trước khi kết thúc live vẫn có hiệu lực đến `expiresAt`; nếu cần chặn tức thì, kiểm duyệt tin nhắn hoặc lưu lịch sử thì phải triển khai thêm cơ chế riêng.
