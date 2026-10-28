# Admin — hướng dẫn tích hợp API

Tài khoản đăng nhập mẫu cho backend local: [TEST_ACCOUNTS.md](../TEST_ACCOUNTS.md).

## Quy ước

- Các API bên dưới cần Bearer access token có role `ADMIN`; base URL lấy theo môi trường backend (`http://localhost:8081` khi chạy local). JSON gửi `Content-Type: application/json`.
- Các nhóm dashboard, podcast moderation, reports và podcast appeals tại `/api/admin/...` cũng cho phép role `STAFF`; nhóm người dùng, danh mục, tài chính và gói vẫn chỉ dành cho Admin.
- API phân trang trả trực tiếp Spring `Page`: dùng `content[]`, `number`, `totalElements`, `totalPages`, với `page` bắt đầu từ `0`. Không giả định response có wrapper `data`.
- `GET /api/admin/dashboard` cung cấp số liệu tổng quan. ID lấy từ danh sách/chi tiết, không dùng tên hiển thị làm ID.

## 1. Duyệt đơn Content Creator

1. `GET /api/admin/creator-applications?status=PENDING&page=0&size=20` lấy hàng đơn; `GET /api/admin/creator-applications/{applicationId}` đọc `channelName`, `introduction`, `portfolioUrl` và chủ đơn.
2. `POST /api/admin/creator-applications/{applicationId}/approve` không body hoặc `{ "note": "Ghi chú" }` (tối đa 2000). Người dùng cần đăng nhập lại/refresh token để nhận role `CREATOR` mới.
3. `POST /api/admin/creator-applications/{applicationId}/reject` với `{ "note": "Lý do từ chối" }` (bắt buộc, tối đa 2000).

## 2. Danh mục

- `GET /api/categories`: danh mục đang hoạt động cho frontend công khai.
- `GET /api/admin/categories` trả `List` tất cả danh mục, kể cả đã vô hiệu hóa; `GET /api/admin/categories/{categoryId}` trả chi tiết.
- `POST /api/admin/categories`: `{ "name": "Lịch sử", "slug": "lich-su", "description": "...", "active": true }`. `name` tối đa 120 và `slug` tối đa 140 là bắt buộc; `description` tối đa 10000, `active` tùy chọn khi tạo.
- `PUT /api/admin/categories/{categoryId}`: cùng trường như tạo nhưng gửi `active` rõ ràng. `DELETE /api/admin/categories/{categoryId}` khi backend cho phép.

## 3. Duyệt podcast, transcript và AI

| Bước | API | Dùng response |
| --- | --- | --- |
| Hàng chờ | `GET /api/admin/podcasts/page?status=PENDING_REVIEW&page=0&size=20` | Danh sách `content[]`. |
| Chi tiết | `GET /api/admin/podcasts/{podcastId}` | `podcast` và `reviews`. |
| Phát media | `GET /api/admin/podcasts/{podcastId}/preview` | URL có hạn `videoUrl`, `expiresAt`. |
| Transcript | `GET /api/admin/podcasts/{podcastId}/transcript` | `fullText`, `segments`, `status`, `errorMessage`. |
| AI feedback | `GET /api/admin/podcasts/{podcastId}/ai-moderation?page=0&size=20` | `content[]`: `overallLabel`, `recommendation`, `reason`, `status`, `current`, `errorMessage`. |
| Lịch sử | `GET /api/admin/podcasts/{podcastId}/reviews?page=0&size=20` | Quyết định Admin/Staff/AI. |
| Nguồn | `GET /api/admin/podcasts/{podcastId}/references` | Metadata nguồn, PDF nếu có. |

Whisper xử lý nền sau khi Creator upload audio/video; submit vẫn nhận `PENDING_REVIEW` nếu transcript chưa xong. AI chờ transcript `COMPLETED`. Nội dung an toàn với khuyến nghị duyệt, khớp phiên bản media/transcript hiện tại, có thể tự chuyển `APPROVED`; các trường hợp còn lại để Admin/Staff xem. AI chỉ dựa trên tiêu đề, mô tả và lời nói trong transcript, không nhận diện hình ảnh/chữ trên video.

- `POST /api/admin/podcasts/{podcastId}/transcript` chạy lại transcript; `POST /api/admin/podcasts/{podcastId}/ai-moderation` chạy lại AI sau khi transcript đã hoàn tất. Không có body; tải lại trạng thái sau đó.
- `POST /api/admin/podcasts/{podcastId}/approve` không body hoặc `{ "note": "Ghi chú" }`; `POST /api/admin/podcasts/{podcastId}/reject` cần `{ "note": "Lý do từ chối" }`.
- Xử lý nội dung sau duyệt: `POST /api/admin/podcasts/{podcastId}/hide` với `{ "note": "Lý do" }`; `DELETE /api/admin/podcasts/{podcastId}` với body `{ "note": "Lý do" }`; `POST /api/admin/podcasts/{podcastId}/restore` với `{ "note": "Lý do" }`.

## 4. Reports và appeals

- Báo cáo: `GET /api/admin/reports?page=0&size=20`, `GET /api/admin/reports/{reportId}`, `POST /api/admin/reports/{reportId}/claim` (không body), `POST /api/admin/reports/{reportId}/resolve` body `{ "action": "DISMISS", "note": "Lý do" }`. `action`: `DISMISS`, `HIDE_CONTENT`, `DELETE_CONTENT`; `note` bắt buộc.
- Khiếu nại: `GET /api/admin/podcast-appeals?page=0&size=20`, `GET /api/admin/podcast-appeals/{appealId}`, `POST /api/admin/podcast-appeals/{appealId}/resolve` body `{ "decision": "ACCEPT", "note": "Lý do" }`. `decision`: `ACCEPT` hoặc `REJECT`.

## 5. Người dùng, Staff và audit

| API | Body / cách dùng |
| --- | --- |
| `GET /api/admin/users?q=&role=&active=&page=0&size=20`, `GET /api/admin/users/{userId}` | Tìm và xem tài khoản. |
| `PATCH /api/admin/users/{userId}` | `{ "displayName": "Tên", "avatarUrl": "https://...", "bio": "..." }`; `displayName` bắt buộc, tối đa 120; `avatarUrl` và `bio` tùy chọn, tối đa 2000 và 5000. |
| `PATCH /api/admin/users/{userId}/access` | `{ "active": false, "note": "Lý do" }`; `active` và `note` bắt buộc, `note` tối đa 5000. |
| `PATCH /api/admin/users/{userId}/verification` | `{ "verified": true, "note": "Lý do" }`. |
| `PATCH /api/admin/users/{userId}/role` | `{ "role": "STAFF", "note": "Lý do" }`; role được đổi thành `LISTENER`, `CREATOR` hoặc `STAFF`. |
| `POST /api/admin/users/{userId}/revoke-sessions` | `{ "note": "Lý do" }` để vô hiệu phiên hiện có. |
| `GET /api/admin/staff?page=0&size=20` | Danh sách Staff. |
| `POST /api/admin/staff` | `{ "username": "staff01", "email": "staff@example.com", "password": "password123", "displayName": "Nhân viên" }`. |
| `GET /api/admin/audit-logs?page=0&size=20` | Lịch sử thao tác. |

## 6. Thanh toán, ví và rút tiền

1. `GET /api/admin/payments?page=0&size=20` (có thể lọc `status`), `GET /api/admin/payments/{paymentId}`: kiểm tra giao dịch và phương thức thanh toán.
2. `POST /api/admin/payments/{paymentId}/reconcile` với `{ "result": "PAID", "providerTransactionId": "mã-giao-dịch", "note": "Đã đối soát" }`. `result` là `PAID` hoặc `FAILED`; `providerTransactionId` cần khi `PAID`, `note` bắt buộc. Chỉ khi payment đủ điều kiện thì tiền mới đi vào luồng giải ngân của Creator.
3. `POST /api/admin/payments/{paymentId}/refund` với `{ "refundReference": "mã-hoàn-tiền", "note": "Lý do" }`.
4. `GET /api/admin/wallets?page=0&size=20`, `GET /api/admin/wallet-transactions?page=0&size=20` (có thể lọc `walletId`, `status`) để kiểm tra sổ ví.
5. Tạo phương thức nhận tiền cho Creator: `POST /api/admin/payouts/creators/{creatorProfileId}/accounts` với `{ "payoutMethod": "BANK", "accountReference": "số/tài khoản", "accountMasked": "****1234", "currency": "VND" }`. Giới hạn lần lượt 40, 255, 160; `currency` đúng 3 chữ cái.
6. Yêu cầu rút tiền tạo từ `POST /api/creator/wallet/withdrawals` đã giữ tiền ngay. Dùng **`GET /api/admin/payouts/withdrawals/pending`** và **`POST /api/admin/payouts/withdrawals/{withdrawalId}/result`** với `{ "result": "SUCCESS", "providerReference": "mã-chuyển-tiền", "note": "..." }`. `result` là `SUCCESS` hoặc `FAILED`; `providerReference` bắt buộc khi `SUCCESS`.

Luồng `POST /api/admin/withdrawals/{id}/approve` cũ giả định chưa giữ tiền, có thể trả `409` đối với withdrawal Creator mới. Frontend Admin nên dùng cặp API `/api/admin/payouts/withdrawals/...` ở bước 6.

## 7. Hợp đồng và tranh chấp

- `GET /api/admin/contracts?page=0&size=20`, `GET /api/admin/contracts/{contractId}` để xem hợp đồng; `GET /api/admin/disputes?status=OPEN&page=0&size=20`, `GET /api/admin/disputes/{disputeId}` để xem tranh chấp.
- Mở tranh chấp cho hợp đồng: `POST /api/admin/contracts/{contractId}/disputes` với `{ "note": "Lý do" }`.
- Giải quyết: `POST /api/admin/disputes/{disputeId}/resolve` với `{ "decision": "RESUME_CONTRACT", "note": "Lý do" }`; `decision` nhận `RESUME_CONTRACT`, `CANCEL_CONTRACT`, `COMPLETE_CONTRACT`.
- Tranh chấp milestone: `GET /api/admin/milestone-disputes/open`; `POST /api/admin/milestone-disputes/{disputeId}/resolve` với `{ "decision": "APPROVE_MILESTONE", "note": "Lý do" }`. `decision` có thể là `REQUEST_REVISION`.

## 8. Quản lý gói

Hai cờ `CREATOR_PLANS_ENABLED=true` và `MEMBERSHIPS_ENABLED=true` bật tính năng gói mặc định. Admin có thể quản lý dữ liệu gói:

- `POST /api/admin/membership-plans` với `{ "creatorId": "UUID", "name": "Tên gói", "description": "...", "price": 100000, "currency": "VND", "durationDays": 30, "status": "ACTIVE" }`; `price` dương, `durationDays` 1–3650, `status` là `ACTIVE`/`INACTIVE`.
- `GET /api/admin/membership-plans?creatorId=<UUID>&page=0&size=20` chỉ trả các gói đang `ACTIVE`; bỏ `creatorId` để xem gói ACTIVE của tất cả kênh. Gói `INACTIVE` không nằm trong danh sách này.
- `POST /api/admin/creator-system-plans` với `{ "code": "PRO", "name": "Gói Pro", "description": "...", "price": 100000, "currency": "VND", "durationDays": 30, "status": "ACTIVE", "benefits": [{ "key": "BENEFIT_KEY", "value": "giá trị", "description": "..." }] }`.
- Các endpoint CRUD cùng nhóm `/api/admin/membership-plans` và `/api/admin/creator-system-plans` phục vụ quản trị. Đặt cờ tương ứng thành `false` nếu cần tạm tắt một loại gói.

## 9. Thông báo của tài khoản Admin

Admin không có endpoint feed riêng dưới `/api/admin/notifications`. Nếu màn hình Admin cần đọc thông báo gắn với chính tài khoản đang đăng nhập, dùng:

- `GET /api/me/notifications?page=0&size=20` — đọc `content[]` và các field `notificationId`, `type`, `title`, `message`, `read`, `createdAt`, `readAt`, `payload`.
- `PUT /api/me/notifications/{notificationId}/read` — body rỗng, thành công `204`.
- Realtime: STOMP `ws://<backend-host>/ws`, gửi `Authorization: Bearer <accessToken>` trong frame `CONNECT`, subscribe `/user/queue/notifications`.

Các API `/api/admin/...` vẫn dùng để đọc trạng thái nghiệp vụ (payment, report, podcast, gói); không dùng chúng để lấy danh sách notification. Contract WebSocket, reconnect và phân loại event xem tại [docs/notifications/README.md](../notifications/README.md).

## Lỗi thường gặp

`400`: body sai/thiếu trường. `401`: token sai/hết hạn. `403`: thiếu role Admin. `404`: không thấy ID. `409`: xung đột trạng thái hoặc tính năng gói đang tắt.
