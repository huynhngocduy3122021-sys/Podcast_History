# Notifications — Frontend API theo role

Tài liệu này là contract chung cho màn hình thông báo của Frontend. Endpoint REST và WebSocket dùng cùng một định danh người dùng lấy từ access token; Frontend **không truyền `userId`** trên URL.

## 1. Quy ước chung

- Base URL local: `http://localhost:8081`; Android Emulator: `http://10.0.2.2:8081`.
- Tất cả request bên dưới cần `Authorization: Bearer <accessToken>`.
- `GET /api/me/notifications` trả trực tiếp Spring `Page`, không có wrapper `data`.
- `page` bắt đầu từ `0`; `size` hợp lệ được giới hạn trong khoảng `1..100` (mặc định `20`).
- `payload` có thể là `null`; không ép kiểu payload thành chuỗi khi đọc.

## 2. REST fallback — áp dụng cho mọi role đã đăng nhập

### Lấy danh sách

```http
GET /api/me/notifications?page=0&size=20
Authorization: Bearer <accessToken>
```

Response mẫu:

```json
{
  "content": [
    {
      "notificationId": "<uuid>",
      "type": "NEW_COMMENT",
      "title": "Người nghe bình luận về podcast",
      "message": "Người nghe vừa bình luận về podcast.",
      "read": false,
      "createdAt": "2026-10-28T09:00:00Z",
      "readAt": null,
      "payload": {
        "podcastId": "<uuid>",
        "commentId": "<uuid>",
        "listenerId": "<uuid>"
      }
    }
  ],
  "number": 0,
  "size": 20,
  "totalElements": 1,
  "totalPages": 1,
  "first": true,
  "last": true
}
```

Frontend đọc các field `notificationId`, `type`, `title`, `message`, `read`, `createdAt`, `readAt`, `payload`. Khi mở một thông báo, đánh dấu đã đọc:

```http
PUT /api/me/notifications/{notificationId}/read
Authorization: Bearer <accessToken>
```

Body rỗng; thành công trả `204 No Content`. Chỉ người sở hữu thông báo mới đánh dấu được; ID của người khác trả `404`.

Khởi động màn hình bằng REST trước để không mất thông báo khi WebSocket đang reconnect. Khi reconnect thành công, tải lại trang đầu một lần để bù các event đã bỏ lỡ.

## 3. WebSocket/STOMP realtime — áp dụng cho mọi role đã đăng nhập

### Kết nối

```text
ws://localhost:8081/ws
```

Production dùng `wss://<backend-host>/ws`. Gửi JWT trong **STOMP CONNECT native header**, không phải query string:

```text
CONNECT
accept-version:1.2
Authorization:Bearer <accessToken>

\0
```

Backend xác thực claim `user_id` trong token. Sau khi nhận `CONNECTED`, subscribe đúng user destination:

```text
SUBSCRIBE
id:notifications
destination:/user/queue/notifications

\0
```

Mỗi message có cùng schema với một phần tử trong `content[]` của REST (`notificationId`, `type`, `title`, `message`, `read`, `createdAt`, `readAt`, `payload`). Không subscribe `/queue/notifications` trực tiếp và không thêm `userId` vào destination.

Nếu không cần nhận realtime nữa, `UNSUBSCRIBE` rồi đóng STOMP/WebSocket connection. Khi token hết hạn hoặc nhận lỗi CONNECT, refresh token theo flow đăng nhập rồi kết nối lại.

## 4. Phân theo role và loại thông báo

Một endpoint được dùng chung cho Listener, Creator/CC, Staff và Admin. Role chỉ quyết định loại nghiệp vụ có thể phát sinh thông báo.

### Listener

| `type` | Khi phát sinh | `payload` thường có |
| --- | --- | --- |
| `NEW_PODCAST` | Kênh đang theo dõi có podcast mới đủ điều kiện nghe | `podcastId`, `creatorId` |
| `REPORT_RESULT` | Admin/Staff xử lý report do Listener gửi | thường không có |
| `PAYMENT_RESULT` / `PAYMENT_REFUND` | Thanh toán hoặc hoàn tiền của Listener được xử lý | thường không có |
| `CONTRACT_DISPUTE` / `DISPUTE_RESULT` | Tranh chấp hợp đồng của Listener mở/được giải quyết | thường không có |
| `CREATOR_APPLICATION` | Đơn đăng ký Creator được duyệt/từ chối | thường không có |
| `ACCOUNT_ACCESS` / `ACCOUNT_ROLE` | Admin đổi trạng thái truy cập hoặc role tài khoản | thường không có |

### Creator / Content Creator (CC)

| `type` | Khi phát sinh | `payload` thường có |
| --- | --- | --- |
| `NEW_FOLLOWER` | Listener theo dõi kênh | `creatorId`, `listenerId` |
| `NEW_COMMENT` | Listener bình luận vào podcast của CC | `podcastId`, `commentId`, `listenerId` |
| `NEW_MEMBERSHIP` | Membership chuyển `ACTIVE` sau khi thanh toán xác nhận | `creatorId`, `subscriptionId`, `membershipPlanId`, `listenerId` |
| `NEW_PODCAST` | CC theo dõi một kênh khác và kênh đó có podcast mới | `podcastId`, `creatorId` |
| `PODCAST_REVIEW` / `PODCAST_MODERATION` | Staff/Admin/AI duyệt hoặc xử lý podcast | thường không có |
| `PAYMENT_RESULT` / `PAYMENT_REFUND` | Thanh toán liên quan nội dung/gói của CC được xử lý | thường không có |
| `CONTRACT_DISPUTE` / `DISPUTE_RESULT` | Hợp đồng của CC có tranh chấp hoặc được giải quyết | thường không có |
| `ACCOUNT_ACCESS` / `ACCOUNT_ROLE` | Admin đổi trạng thái truy cập hoặc role | thường không có |

`NEW_MEMBERSHIP` chỉ phát sinh khi membership được xác nhận thành công; checkout `PENDING` chưa tạo loại thông báo này.

### Staff

Staff vẫn dùng `GET /api/me/notifications`, `PUT /api/me/notifications/{notificationId}/read` và WebSocket destination như trên. Backend hiện không có loại thông báo nghiệp vụ riêng gửi cho Staff; không dùng `/api/admin/notifications` vì endpoint đó không tồn tại.

### Admin

Admin cũng dùng đúng hai endpoint `/api/me/notifications` và destination `/user/queue/notifications`. Backend không có feed thông báo quản trị riêng; các màn hình quản trị lấy dữ liệu nghiệp vụ bằng các API `/api/admin/...` tương ứng. Không gọi endpoint `/api/admin/notifications`.

## 5. Xử lý lỗi và reconnect

| HTTP/STOMP | Frontend xử lý |
| --- | --- |
| `401` REST | Refresh token một lần, thay cả hai token rồi gọi lại; thất bại thì đăng nhập lại |
| `404` khi mark read | Xóa item khỏi UI hoặc tải lại danh sách vì thông báo không thuộc user hiện tại |
| CONNECT bị từ chối | Kiểm tra STOMP header `Authorization: Bearer ...`, token còn hạn và claim `user_id` |
| Mất WebSocket | Giữ dữ liệu REST hiện có, reconnect có backoff; khi kết nối lại gọi GET trang đầu |

Thông báo được gửi sau khi bản ghi database commit thành công. Nếu tại thời điểm đó không có WebSocket client đang subscribe, bản ghi vẫn còn trong REST để Frontend tải lại.

