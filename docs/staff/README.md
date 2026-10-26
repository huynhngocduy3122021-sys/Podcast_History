# Staff — hướng dẫn tích hợp API

Tài khoản đăng nhập mẫu cho backend local: [TEST_ACCOUNTS.md](../TEST_ACCOUNTS.md).

## Quy ước

- Tất cả API dưới đây yêu cầu `Authorization: Bearer <accessToken>` có role `STAFF`. Các chức năng dùng chung sử dụng URL `/api/admin/...` cho cả Admin và Staff. Base URL lấy theo môi trường backend đang chạy (local thường `http://localhost:8081`).
- Gửi JSON với `Content-Type: application/json`. `GET` có `page`, `size` trả Spring `Page`, danh sách nằm trong `content`; `page` bắt đầu từ `0`.
- Dùng `podcastId`, `reportId`, `appealId` từ response danh sách; không dùng thứ tự hiển thị làm ID. `POST` thao tác trạng thái không cần body nếu không ghi body bên dưới.

## 1. Hàng chờ duyệt podcast

| Bước | API | Dữ liệu frontend dùng |
| --- | --- | --- |
| Tổng quan | `GET /api/admin/dashboard` | Số liệu trên dashboard. |
| Hàng chờ | `GET /api/admin/podcasts/page?status=PENDING_REVIEW&page=0&size=20` | `content[]`, `totalElements`. Có thể đổi bộ lọc `status`. |
| Chi tiết | `GET /api/admin/podcasts/{podcastId}` | `podcast` và `reviews`; xem title, description, status, mediaKey, thumbnailUrl. |
| Phát media | `GET /api/admin/podcasts/{podcastId}/preview` | `videoUrl` có hạn dùng `expiresAt`; lấy lại khi URL hết hạn. |
| Transcript | `GET /api/admin/podcasts/{podcastId}/transcript` | `status`, `fullText`, `segments`, `language`, `modelName`, `errorMessage`; `fullText` có nội dung khi `COMPLETED`. |
| AI | `GET /api/admin/podcasts/{podcastId}/ai-moderation?page=0&size=20` | Trong `content[]` xem `status`, `overallLabel`, `recommendation`, `reason`, `errorMessage`, `current`, `transcriptId`. |
| Lịch sử duyệt | `GET /api/admin/podcasts/{podcastId}/reviews?page=0&size=20` | Đọc các quyết định trước đó; reviewer `AI` khi hệ thống tự duyệt. |
| Nguồn tham khảo | `GET /api/admin/podcasts/{podcastId}/references` | Danh sách nguồn, metadata và file PDF nếu có. |

Frontend nên hiển thị transcript và AI feedback riêng, kèm trạng thái đang xử lý. Khi transcript `PENDING`/`PROCESSING`, AI có thể chưa có kết quả. AI `SAFE` + `APPROVE` phù hợp nội dung hiện tại có thể tự duyệt; bản ghi sẽ rời hàng `PENDING_REVIEW`. AI `FAILED`, `ERROR` hoặc khuyến nghị `REVIEW` là trường hợp cần người duyệt.

Nếu xử lý nền lỗi, Staff có thể gọi `POST /api/admin/podcasts/{podcastId}/transcript` để chạy lại Whisper và `POST /api/admin/podcasts/{podcastId}/ai-moderation` khi transcript đã `COMPLETED`. Cả hai không có body. Sau đó tải lại transcript/AI; không coi HTTP thành công của retry là đã có kết quả cuối.

## 2. Quyết định duyệt

- `POST /api/admin/podcasts/{podcastId}/approve`: có thể không gửi body hoặc gửi `{ "note": "Ghi chú nội bộ" }`.
- `POST /api/admin/podcasts/{podcastId}/reject`: gửi `{ "note": "Lý do từ chối để Creator biết và sửa" }`; `note` là bắt buộc.
- Sau thao tác, tải lại chi tiết và hàng chờ. Chỉ hiển thị nút khi podcast còn ở trạng thái backend cho phép; status xung đột thường trả `409`.

## 3. Báo cáo vi phạm và kiểm soát nội dung

1. `GET /api/admin/reports?page=0&size=20` để xem hàng báo cáo; `GET /api/admin/reports/{reportId}` để xem chi tiết.
2. `POST /api/admin/reports/{reportId}/claim` (không body) để nhận xử lý.
3. `POST /api/admin/reports/{reportId}/resolve` với `{ "action": "DISMISS", "note": "Lý do xử lý" }`. `action` là `DISMISS`, `HIDE_CONTENT` hoặc `DELETE_CONTENT`; `note` bắt buộc.
4. Xử lý trực tiếp podcast khi cần: `POST /api/admin/podcasts/{podcastId}/hide` với `{ "note": "Lý do" }`; `DELETE /api/admin/podcasts/{podcastId}` với body `{ "note": "Lý do" }`; `POST /api/admin/podcasts/{podcastId}/restore` với `{ "note": "Lý do" }`.

## 4. Khiếu nại của Creator

`GET /api/admin/podcast-appeals?page=0&size=20` để xem hàng; `GET /api/admin/podcast-appeals/{appealId}` để đọc nội dung và podcast liên quan. `POST /api/admin/podcast-appeals/{appealId}/resolve` với `{ "decision": "ACCEPT", "note": "Giải thích quyết định" }`; `decision` nhận `ACCEPT` hoặc `REJECT`, `note` cần ghi lý do rõ ràng. Tải lại chi tiết/hàng sau khi xử lý.

## Lỗi thường gặp

`401`: token không hợp lệ/hết hạn. `403`: token thiếu role `STAFF` hoặc không có quyền trên thao tác. `404`: ID không tồn tại. `409`: trạng thái đã thay đổi hoặc tác vụ đang/đã được xử lý. `400`: dữ liệu quyết định thiếu/sai giá trị.
