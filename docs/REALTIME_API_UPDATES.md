# Cập nhật màn hình qua WebSocket

Backend dùng STOMP WebSocket `GET /ws`. FE kết nối với header STOMP `CONNECT Authorization: Bearer <access_token>` và đăng ký các user queue sau. Không gửi lệnh ghi dữ liệu qua WebSocket; dùng HTTP API hiện có.

| Queue | Khi nào phát | FE xử lý |
| --- | --- | --- |
| `/user/queue/api-changes` | Một HTTP `POST`, `PUT`, `PATCH`, `DELETE` có JWT của người gọi hoàn tất với mã 2xx | Gọi lại GET của màn hình liên quan; cập nhật state, không reload trang. |
| `/user/queue/api-changes` | Một thông báo mới được lưu cho tài khoản | Cập nhật badge/danh sách thông báo và, theo `notificationType`, gọi lại GET của nghiệp vụ liên quan. |
| `/user/queue/notifications` | Thông báo mới | Hiển thị nội dung thông báo. |
| `/user/queue/realtime` | Một số luồng riêng như thanh toán SePay | Cập nhật ví, checkout hoặc trạng thái tương ứng. |
| `/user/queue/contract-chat` | Tin nhắn hợp đồng mới | Thêm tin vào đúng cuộc trò chuyện. |

Event HTTP thành công có dạng:

```json
{
  "type": "API_CHANGED",
  "data": {
    "method": "POST",
    "route": "/api/milestones/{milestoneId}/disputes",
    "occurredAt": "2026-10-31T03:00:00Z"
  }
}
```

`route` là mẫu route, không chứa ID, query string, request body hay dữ liệu riêng tư. FE đã biết ID và GET đang dùng ở màn hình hiện tại; sau event chỉ gọi lại những GET đó. Event thông báo mới có `type: NOTIFICATION_CHANGED`, `data.notificationId` và `data.notificationType`.

Ví dụ: sau khi Listener mở tranh chấp, Listener nhận `API_CHANGED` nên tải lại GET chi tiết tranh chấp; CC nhận `NOTIFICATION_CHANGED` và notification `DISPUTE_CONFIRM_REQUIRED`, rồi tải lại GET danh sách/chi tiết tranh chấp. Sau khi Staff quyết định, hai bên nhận `DISPUTE_RESULT` và tải lại hợp đồng, đợt, ví khi màn hình đó đang mở.

Chỉ request HTTP ghi thành công có JWT mới tự phát `API_CHANGED` cho **người gọi**. Request lỗi 4xx/5xx, GET và webhook công khai không phát sự kiện này. Các bên khác được cập nhật khi nghiệp vụ tạo thông báo cho họ. Nếu một luồng nghiệp vụ chưa tạo thông báo cho người liên quan, cần bổ sung event ở chính luồng đó; kênh chung không tự suy ra mọi người bị ảnh hưởng. Với job chạy nền hoặc webhook SePay, dùng event riêng của nghiệp vụ. Khi mất kết nối rồi kết nối lại, FE phải gọi GET để đồng bộ trạng thái vì WebSocket không lưu backlog sự kiện.

Backend chỉ phát tín hiệu; FE phải SUBSCRIBE và cập nhật state hoặc gọi lại GET. Không có cách Backend tự thay dữ liệu đang hiển thị trong trình duyệt khi FE chưa xử lý event.
