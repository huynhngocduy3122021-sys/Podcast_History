# Tạm tắt chức năng gói

Backend mặc định tắt hai loại gói:

```properties
CREATOR_PLANS_ENABLED=false
MEMBERSHIPS_ENABLED=false
```

- Creator được upload audio/video không bị giới hạn theo gói. `GET /api/creator/system-plans` trả `[]`; `GET /api/creator/system-plans/me` trả trạng thái `DISABLED` và số upload đã dùng. API đăng ký gói trả lỗi 409.
- Người nghe không cần membership để nghe podcast độc quyền hoặc gửi yêu cầu podcast. `GET /api/creators/{creatorId}/membership-plans` trả `[]`; API tạo checkout trả lỗi 409. Admin không thể xác nhận thanh toán membership mới khi tính năng đang tắt.
- Subscription, payment, plan và cờ `isExclusive` đã lưu vẫn nằm trong database. API xem lịch sử subscription và công cụ quản trị gói vẫn dùng được.

Frontend mặc định ẩn chỗ mua gói, giới hạn 5 podcast và lựa chọn nội dung độc quyền. Khi cần bật lại, đặt từng biến backend thành `true`, đồng thời build frontend với `--dart-define=PACKAGES_ENABLED=true`. Nếu chỉ bật một loại gói trên backend, cần điều chỉnh cờ giao diện tương ứng trước khi phát hành.
