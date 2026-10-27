# Content Creator — hướng dẫn tích hợp API

Chat trong livestream dùng Agora Signaling, không lưu tin nhắn ở backend: xem [AGORA_LIVE_CHAT.md](AGORA_LIVE_CHAT.md).

## Quy ước chung

- Base URL lấy theo môi trường backend đang chạy (local thường là `http://localhost:8081`; Android Emulator dùng `http://10.0.2.2:8081`). Không hardcode URL ngrok.
- Trừ đăng ký/đăng nhập và `GET /api/categories`, gửi `Authorization: Bearer <accessToken>`. JSON dùng `Content-Type: application/json`; upload dùng `multipart/form-data` với part tên `file`.
- Các API phân trang trả trực tiếp `Page` của Spring (`content`, `number`, `size`, `totalElements`, `totalPages`), không có wrapper `data`. `page` bắt đầu từ `0`.
- Tài khoản mới là `LISTENER`. Để có role `CREATOR`, nộp đơn rồi chờ Admin duyệt; đăng nhập lại hoặc refresh token sau khi duyệt.

## 1. Đăng ký kênh Creator

1. `POST /api/auth/register`: `{ "username": "creator01", "email": "creator@example.com", "password": "password123", "displayName": "Tên hiển thị" }`. `username` dài 3–50, `password` 8–72, `displayName` tối đa 120 ký tự.
2. `POST /api/auth/login`: `{ "identifier": "creator@example.com", "password": "password123" }`; giữ `accessToken` và `refreshToken`. Hết hạn token: `POST /api/auth/refresh` với `{ "refreshToken": "..." }`.

   Nếu login trả `401`, đọc trường `message`: `Tài khoản không tồn tại.`, `Sai mật khẩu.` hoặc `Tài khoản của bạn đã bị khóa.` tùy trường hợp. Backend kiểm tra mật khẩu trước trạng thái khóa.
3. `POST /api/creator-applications`: `{ "channelName": "Tên kênh", "introduction": "Giới thiệu", "portfolioUrl": "https://example.com" }`. `channelName` tối đa 150, `introduction` tối đa 5000; `portfolioUrl` tùy chọn, tối đa 2000.
4. `GET /api/creator-applications/me` để xem trạng thái đơn. Khi được duyệt, lấy token mới có role `CREATOR`.

## 2. Dashboard và danh mục

| API | Dùng để làm gì |
| --- | --- |
| `GET /api/creator/dashboard?period=7d` | Tổng quan; `period` nhận `7d`, `4w`, `12m`. Đọc `profile`, `metrics`, `growth`, `recentPodcasts`, `incomingRequests`. |
| `GET /api/categories` | Danh mục đang hoạt động để chọn `categoryId`; không cần token. |
| `GET /api/creator/podcasts` | Trả `List` podcast của kênh hiện tại, không phân trang. |

## 3. Tạo và phát hành podcast

Gọi các bước theo thứ tự sau. `podcastId` là ID trả về từ bước tạo bản nháp; không gọi `POST /api/creator/podcasts` lần nữa khi cần upload hoặc submit bản nháp đó.

1. **Tạo bản nháp:** `POST /api/creator/podcasts`, body JSON:

   ```json
   {
     "categoryId": "UUID danh mục đang hoạt động",
     "title": "Tiêu đề podcast",
     "description": "Mô tả tập",
     "durationSeconds": 120,
     "episodeNumber": 1,
     "visibility": "PUBLIC"
   }
   ```

   `categoryId`, `title` (tối đa 220 ký tự), `durationSeconds` (1–86400) là bắt buộc. `description` tối đa 10000, `episodeNumber` từ 1 là tùy chọn. `visibility` là `PUBLIC` hoặc `MEMBERS_ONLY`. Có thể dùng `exclusive` boolean kiểu cũ thay cho `visibility`; nếu gửi cả hai thì phải nhất quán. `thumbnailUrl` tối đa 2000 ký tự là tùy chọn, nhưng nếu có file ảnh hãy dùng API upload ảnh ở bước sau.

2. **Upload ảnh bìa (tùy chọn):** `POST /api/creator/podcasts/{podcastId}/thumbnail`, `multipart/form-data`, part `file` chứa JPEG/PNG/WebP/GIF/AVIF/HEIC/HEIF. Backend upload ảnh và cập nhật `thumbnailUrl` vào chính bản nháp. Frontend đọc lại `thumbnailUrl` từ response hoặc `GET` chi tiết; không cần API GET để tạo URL trước.
3. **Upload audio hoặc video (bắt buộc trước submit):** `POST /api/creator/podcasts/{podcastId}/video`, `multipart/form-data`, part `file`. Đường dẫn `/video` dùng chung cho audio và video. Audio hỗ trợ MP3/M4A/AAC/WAV/OGG/OPUS/FLAC; video hỗ trợ MP4/WEBM/MOV/M4V/MKV/3GP/AVI. Giới hạn mặc định 100 MB. Response có `podcastId`, `status` và `media.objectKey`/`media.contentType`; object key không phải URL phát công khai. Gọi `GET /api/creator/podcasts/{podcastId}` để lấy `mediaKey`, `mediaType`, `videoUrl` có hạn dùng cùng `videoUrlExpiresAt`.
4. **Gắn series nếu có:** tạo bằng `POST /api/creator/series` với `{ "categoryId": "UUID", "title": "Tên series", "slug": "ten-series", "description": "...", "coverUrl": "https://..." }`. Ba trường đầu bắt buộc; `title` tối đa 200, `slug` tối đa 220, `description` tối đa 10000, `coverUrl` tối đa 2000. Sau đó `PUT /api/creator/podcasts/{podcastId}/series` với `{ "seriesId": "UUID" }`. `DELETE` cùng URL để bỏ gắn. Có thể lấy danh sách/chi tiết series bằng `GET /api/creator/series`, `GET /api/creator/series/{seriesId}`, `GET /api/creator/series/{seriesId}/podcasts`.
5. **Nguồn tham khảo nếu có:** `POST /api/creator/podcasts/{podcastId}/references` với `{ "referenceType": "WEBSITE", "title": "Tên nguồn", "url": "https://example.com", "author": "...", "publisher": "...", "publishedYear": 2026, "citationText": "..." }`. `referenceType` nhận `BOOK`, `ARTICLE`, `WEBSITE`, `PDF`, `OTHER`; `title` tối đa 300 là bắt buộc. `author`/`publisher` tối đa 200, `url` phải là HTTP(S) và tối đa 2000, `citationText` tối đa 10000. Nếu loại PDF, upload file bằng `POST /api/creator/podcasts/{podcastId}/references/{referenceId}/file`, part `file` là PDF hợp lệ. Xem danh sách qua `GET /api/creator/podcasts/{podcastId}/references`.
6. **Gửi duyệt:** `POST /api/creator/podcasts/{podcastId}/submit`, không có body. Podcast sang `PENDING_REVIEW`. Response thành công chỉ xác nhận đã submit, chưa đồng nghĩa AI/Admin đã duyệt.

### Transcript, AI và trạng thái sau submit

- Upload media thành công sẽ tạo transcript cho đúng `mediaKey`; backend tự gửi media cho Whisper. Frontend không gọi trực tiếp Whisper.
- Transcript chuyển `PENDING` → `PROCESSING` → `COMPLETED` hoặc `FAILED`. Submit khi transcript đang chạy vẫn được: AI chờ transcript hoàn tất rồi phân tích tiêu đề, mô tả và lời nói có timestamp. AI hiện không xét hình ảnh/chữ trên video.
- Chủ kênh gọi chung `GET /api/podcast-transcripts/{podcastId}` bằng token `CREATOR` để xem transcript của chính podcast mình, kể cả bản nháp/chờ duyệt. Response gồm `podcastId`, `status`, `fullText`, `segments`, `language`, `modelName`, `errorMessage`, `processedAt`; khi chưa `COMPLETED`, `fullText` có thể là `null`. Nếu chưa có bản ghi transcript, API trả `404`.
- Endpoint này cũng dùng cho Listener, nhưng luôn yêu cầu đăng nhập; Listener chỉ nhận transcript `COMPLETED` của podcast có quyền nghe. Không có endpoint transcript công khai.
- Kết quả `SAFE` kèm đề xuất `APPROVE` phù hợp nội dung hiện tại có thể tự chuyển podcast sang `APPROVED`. Các trường hợp khác chờ Staff/Admin xem. Frontend theo dõi bằng `GET /api/creator/podcasts/{podcastId}` và `GET /api/creator/podcasts/{podcastId}/reviews?page=0&size=20` để đọc lý do duyệt/từ chối.
- Chỉ chỉnh sửa bản `DRAFT` hoặc `REJECTED`; `PENDING_REVIEW` không sửa được. `PUT /api/creator/podcasts/{podcastId}` dùng lại toàn bộ body tạo bản nháp; khi cập nhật hãy giữ `thumbnailUrl` hiện có nếu muốn giữ ảnh. Chỉnh sửa bản đã duyệt/đăng làm quay lại `DRAFT`. `DELETE /api/creator/podcasts/{podcastId}` đánh dấu xóa.
- Khi bị từ chối, `POST /api/creator/podcasts/{podcastId}/appeals` với `{ "note": "Lý do khiếu nại" }` (bắt buộc, tối đa 5000); `GET` cùng URL để xem các đơn.

## 4. Poll của Creator

- `POST /api/creator/polls`: `{ "question": "Câu hỏi?", "options": ["A", "B"], "seriesId": "UUID tùy chọn", "podcastId": "UUID tùy chọn", "startsAt": "ISO-8601 tùy chọn", "endsAt": "ISO-8601 tùy chọn" }`. `question` bắt buộc, tối đa 5000; có 2–20 `options`, mỗi lựa chọn tối đa 300.
- `GET /api/creator/polls?status=DRAFT&page=0&size=20`, `GET /api/creator/polls/{pollId}` để quản lý. `PUT /api/creator/polls/{pollId}` dùng cùng body lúc tạo khi còn `DRAFT`.
- `POST /api/creator/polls/{pollId}/publish`, `POST /api/creator/polls/{pollId}/close` không cần body; `GET /api/creator/polls/{pollId}/results` và `/responses` để xem kết quả; `DELETE /api/creator/polls/{pollId}` để xóa theo trạng thái cho phép.

## 5. Yêu cầu đặt podcast và ví

1. `GET /api/creator/requests/incoming` để xem yêu cầu từ listener.
2. Nhận yêu cầu bằng `POST /api/creator/requests/{requestId}/accept`:

   ```json
   {
     "responseText": "Tôi nhận thực hiện",
     "milestones": [
       { "name": "Bản thu đầu", "description": "Thu thử", "amount": 100000 }
     ]
   }
   ```

   `responseText` bắt buộc, tối đa 5000. Có 1–30 milestone; mỗi `name` bắt buộc tối đa 150, `description` tối đa 3000, `amount` dương tối đa 2 chữ số thập phân. Muốn từ chối: `POST /api/creator/requests/{requestId}/reject` với `{ "responseText": "Lý do" }`.
3. Nộp sản phẩm milestone: `POST /api/creator/milestones/{milestoneId}/submissions`, multipart `file` audio/video và `note` tùy chọn (tối đa 5000). Xem bằng `GET /api/milestones/{milestoneId}/submissions`.
4. Khi listener chấp nhận sản phẩm và Admin đối soát thanh toán thành `PAID`, gọi `POST /api/creator/wallet/release-funds` (không body). `GET /api/creator/wallet/balance` trả `availableBalance`, `heldBalance`, `pendingRelease`, `currency`; số dư được tính theo thanh toán và phương thức thanh toán, không tự cộng khi chỉ có yêu cầu.
5. `GET /api/creator/wallet/payout-accounts` để chọn tài khoản nhận tiền do Admin cấp. `POST /api/creator/wallet/withdrawals` với `{ "amount": 100000, "payoutAccountId": "UUID" }`; amount phải dương và không vượt số dư khả dụng. `GET /api/creator/wallet/withdrawals` để theo dõi; tiền được giữ ngay khi tạo yêu cầu và Admin xử lý kết quả qua luồng payout.

## 6. Tình trạng gói

Tính năng gói Creator và membership listener đang tắt theo cấu hình mặc định. `GET /api/creator/system-plans` có thể trả `[]`; trạng thái gói của Creator là `DISABLED`, đăng ký gói bị chặn. Frontend nên ẩn nút mua/đăng ký khi nhận trạng thái này.

## Thông báo cho Creator

`GET /api/me/notifications?page=0&size=20` trả `Page`; mỗi phần tử có `notificationId`, `type`, `title`, `message`, `read`, `createdAt`, `readAt` và `payload`. `PUT /api/me/notifications/{notificationId}/read` đánh dấu đã đọc, không cần body, trả `204`.

| `type` | Khi nào tạo | ID trong `payload` |
| --- | --- | --- |
| `NEW_FOLLOWER` | Listener tạo lượt theo dõi mới; gọi PUT lại khi đang theo dõi không tạo thông báo trùng | `creatorId`, `listenerId` |
| `NEW_COMMENT` | Listener bình luận vào podcast của Creator | `podcastId`, `commentId`, `listenerId` |
| `NEW_MEMBERSHIP` | Admin xác nhận thanh toán và membership chuyển `ACTIVE` | `creatorId`, `subscriptionId`, `membershipPlanId`, `listenerId` |

`NEW_MEMBERSHIP` chưa phát sinh khi `MEMBERSHIPS_ENABLED=false`; tạo checkout `PENDING` cũng chưa được tính là mua thành công. Frontend tải lại danh sách thông báo để cập nhật, hiện chưa có luồng push riêng.

## Xử lý lỗi thường gặp

`400` là body/validation, `401` là token hết hạn hoặc sai, `403` là thiếu role `CREATOR` hoặc không sở hữu tài nguyên, `404` là ID không tồn tại, `409` là trạng thái không cho thao tác hoặc tính năng gói đang tắt, `413`/`415` là file quá lớn hoặc sai định dạng.
