# Frontend API — Listener

Hướng dẫn này dùng cho tài khoản `LISTENER` và các màn hình khám phá, nghe, tương tác, poll, yêu cầu podcast. Contract đối chiếu với controller/DTO backend hiện tại. `creatorId` trong URL là `creatorProfileId` của kênh, không phải `userId`.

Chat livestream: sau `POST /api/livestreams/{livestreamId}/join`, gọi `POST /api/livestreams/{livestreamId}/chat-token` (không có body) để nhận token Agora Signaling. Tin nhắn đi trực tiếp qua Agora và không lưu trong database; xem [hướng dẫn chat live](../content-creator/AGORA_LIVE_CHAT.md).

## 1. Kết nối và phiên đăng nhập

- Base URL local: `http://localhost:8081`; Android emulator: `http://10.0.2.2:8081`. Máy khác dùng URL HTTPS ngrok đang chạy, không lưu cố định hostname cũ.
- Các URL dưới đây đã có `/api`. JSON gửi `Content-Type: application/json`; API bảo vệ gửi `Authorization: Bearer <accessToken>`.
- `GET /api/categories`, đăng ký, login, refresh và logout không cần Bearer. Các API khám phá podcast vẫn cần đăng nhập, kể cả podcast `PUBLIC`.
- Nếu qua ngrok, có thể thêm `ngrok-skip-browser-warning: 1`.
- Với response `Page`, đọc `content[]`, `totalElements`, `totalPages`; `page` bắt đầu 0, `size` mặc định 20.

| Thứ tự | API | Dữ liệu gửi | Response cần lưu |
|---:|---|---|---|
| 1 | `POST /api/auth/register` | `username` 3–50, `email` hợp lệ ≤255, `password` 8–72, `displayName` 1–120 | Tài khoản mới role `LISTENER`; chưa có token |
| 2 | `POST /api/auth/login` | `identifier` (username/email), `password` | `accessToken`, `refreshToken`, `user.id`, `user.role` |
| Khi 401 do hết hạn | `POST /api/auth/refresh` | `{"refreshToken":"<token hiện tại>"}` | Thay **cả hai** token rồi gọi lại request một lần |
| Đăng xuất | `POST /api/auth/logout` | `{"refreshToken":"<token hiện tại>"}` | `204` |

Khi `POST /api/auth/login` trả `401`, frontend đọc trường `message`: `Tài khoản không tồn tại.` nếu username/email không có trong database; `Sai mật khẩu.` nếu tài khoản có nhưng mật khẩu không đúng; `Tài khoản của bạn đã bị khóa.` nếu mật khẩu đúng nhưng tài khoản đã bị khóa. Chỉ thông báo lỗi từ request login này; lỗi `401` ở API khác vẫn có thể là token hết hạn.

```json
{"username":"listener01","email":"listener@example.com","password":"MatKhau123!","displayName":"Người nghe"}
```

## 2. Khám phá và nghe podcast

| Bước | API | Query/body | Dữ liệu dùng ở frontend |
|---:|---|---|---|
| 1 | `GET /api/categories` | Không | `categoryId`, `name` để lọc |
| 2 | `GET /api/creators?q=lich%20su` | `q` tên kênh tùy chọn | `creatorProfileId`, `channelName` |
| 3 | `GET /api/podcasts?q=...&categoryId=...&creatorId=...&seriesId=...&page=0&size=20` | Mọi filter tùy chọn; bỏ tham số trống | `content[]` có `podcastId`, `title`, `thumbnailUrl`, `visibility`, `creatorProfileId` |
| 4 | `GET /api/podcasts/{podcastId}` | ID từ bước 3 | Chi tiết tập |
| 5 | `GET /api/podcasts/{podcastId}/playback` | Không body | `playbackUrl`, `expiresAt`, `resumeFromSeconds`, `durationSeconds` |
| 6 | `PUT /api/podcasts/{podcastId}/listening-progress` | `progressSeconds` integer 0–86.400, `completed` boolean | Tiến độ đã lưu |
| Lần mở sau | `GET /api/me/listening-history/{podcastId}` hoặc `GET /api/me/listening-history?page=0&size=20` | Không body | Vị trí đã nghe, danh sách lịch sử |

```json
{"progressSeconds":125,"completed":false}
```

Khi phát hết, gửi `completed: true`. Signed `playbackUrl` có thể hết hạn; lấy lại bằng `/playback` khi cần. `DELETE /api/me/listening-history/{podcastId}` xóa lịch sử của chính người nghe. Danh sách tìm kiếm chỉ gồm podcast đã duyệt/xuất bản; bản nháp không công khai.

### Xem transcript

- `GET /api/podcast-transcripts/{podcastId}`: gửi token `LISTENER`. Đây là cùng endpoint chủ kênh dùng; Listener chỉ xem transcript `COMPLETED` của podcast có quyền nghe, gồm `MEMBERS_ONLY` khi quyền nghe hợp lệ.
- Response gồm `podcastId`, `status`, `language`, `modelName`, `fullText`, `segments` (các đoạn có timestamp), `errorMessage` (luôn `null` cho Listener) và `processedAt`. `404` nghĩa là podcast không thể truy cập hoặc transcript chưa hoàn tất. Frontend có thể ẩn nút Transcript hoặc hiển thị “Chưa có bản chép lời”. Không có API transcript công khai không cần đăng nhập.

## 3. Tương tác trên podcast

| Màn hình | API | Dữ liệu nhập |
|---|---|---|
| Số lượt thích | `GET /api/podcasts/{podcastId}/likes` | Không; response `likeCount`, `likedByMe` |
| Thích/bỏ thích | `PUT` / `DELETE /api/podcasts/{podcastId}/like` | Không body |
| Danh sách bình luận | `GET /api/podcasts/{podcastId}/comments?page=0&size=20` | Không; response Page, mỗi comment có `likeCount` và `likedByMe` |
| Gửi bình luận | `POST /api/podcasts/{podcastId}/comments` | `content` không rỗng ≤5.000, `timestampSeconds` tùy chọn ≥0 và không quá độ dài tập |
| Sửa/xóa bình luận của mình | `PUT /api/comments/{commentId}` body `{content}`; `DELETE` cùng URL | PUT giữ nguyên timestamp cũ |
| Số lượt thích comment | `GET /api/comments/{commentId}/likes` | Không; trả `{commentId, likeCount, likedByMe}` |
| Thích/bỏ thích comment | `PUT` / `DELETE /api/comments/{commentId}/like` | Không body; trả `{commentId, likeCount, likedByMe}`; gọi lặp không tạo like trùng |
| Bình luận mới | `GET /api/podcasts/{podcastId}/comments/stream` | SSE, `Accept: text/event-stream`; mất kết nối thì tải GET comments lại |
| Theo dõi/bỏ theo dõi kênh | `PUT` / `DELETE /api/creators/{creatorId}/follow` | Không body |
| Kênh theo dõi | `GET /api/me/follows?page=0&size=20` | Không |
| Lưu/bỏ lưu podcast | `PUT` / `DELETE /api/me/saved-podcasts/{podcastId}` | Không body |
| Danh sách đã lưu | `GET /api/me/saved-podcasts?page=0&size=20` | Không |

Ví dụ comment tại phút 18: `{"content":"Đoạn này rất rõ","timestampSeconds":1080}`. `timestampSeconds` lấy từ vị trí player lúc nhấn gửi, không phải thời gian đồng hồ. Danh sách đã lưu hiện là một danh sách chung; chưa có nhiều playlist đặt tên.

Like comment chỉ áp dụng cho bình luận còn hiển thị của podcast đã phát hành. Nếu bình luận bị xóa/ẩn hoặc podcast không còn hiển thị, API like trả `404`.

## 4. Báo cáo, nguồn tham khảo, thông báo

| Tác vụ | API | Body/query |
|---|---|---|
| Báo cáo podcast/comment | `POST /api/reports` | `targetType`: `PODCAST` hoặc `COMMENT`; `targetId` UUID; `reasonCode` không rỗng ≤50; `description` tùy chọn ≤5.000 |
| Lịch sử báo cáo | `GET /api/me/reports?page=0&size=20` | Không |
| Sửa/rút báo cáo PENDING | `PATCH /api/me/reports/{reportId}` body `reasonCode`, `description`; `DELETE` cùng URL | Chỉ sửa/rút khi chưa xử lý |
| Nguồn podcast | `GET /api/podcasts/{podcastId}/references` | Lấy `referenceId` |
| Tải PDF nguồn | `GET /api/podcasts/{podcastId}/references/{referenceId}/file` | Dùng `downloadUrl`, lấy lại khi link hết hạn |
| Thông báo | `GET /api/me/notifications?page=0&size=20` | Page thông báo |
| Đánh dấu đã đọc | `PUT /api/me/notifications/{notificationId}/read` | Không body; `204` |

Khi kênh đang theo dõi có podcast mới được duyệt mà listener có quyền nghe, listener nhận thông báo `NEW_PODCAST`. Khi gói membership đang tắt, cả tập `MEMBERS_ONLY` cũng nghe được theo luồng playback hiện tại. Mỗi phần tử trong `content[]` của API thông báo có `notificationId`, `type`, `title`, `message`, `read`, `createdAt`, `readAt` và `payload`. Với `NEW_PODCAST`, `payload` có `podcastId` và `creatorId`; dùng `podcastId` để mở chi tiết.

Để nhận thông báo ngay khi có bản ghi mới, mở STOMP tại `/ws` bằng Bearer token trong frame `CONNECT`, sau đó subscribe `/user/queue/notifications`. REST ở trên vẫn là fallback bắt buộc khi mở màn hình và sau mỗi lần reconnect. Xem contract đầy đủ, schema, reconnect và các loại thông báo theo role tại [docs/notifications/README.md](../notifications/README.md).

```json
{"targetType":"PODCAST","targetId":"<podcastId>","reasonCode":"INAPPROPRIATE","description":"Lý do cụ thể"}
```

## 5. Poll của kênh

1. `GET /api/creators/{creatorId}/polls?seriesId=...&podcastId=...&page=0&size=20` để xem poll đã công bố; hai filter tùy chọn.
2. `GET /api/polls/{pollId}` để đọc câu hỏi và `options[].optionId`.
3. `POST /api/polls/{pollId}/responses` body `{"optionId":"<optionId>"}` để gửi lần đầu.
4. `GET /api/polls/{pollId}/responses/me` đọc lựa chọn của mình; `GET /api/polls/{pollId}/results` đọc thống kê.
5. Khi poll còn nhận trả lời, `PUT /api/polls/{pollId}/responses/me` cùng body để đổi hoặc `DELETE` URL đó để rút.

Gửi POST lần hai trả xung đột; dùng PUT để đổi. Frontend dựa `acceptingResponses` trong chi tiết poll để bật nút gửi. `404` ở `/responses/me` có nghĩa chưa trả lời.

## 6. Yêu cầu Creator làm podcast

Backend có hai nhóm API. **Chọn một nhóm cho một hành trình UI**, vì nhóm đơn giản và nhóm có milestone không cùng cách cập nhật.

### 6.1 Đơn có báo giá, hợp đồng và milestone

| Bước | API | Body/kết quả |
|---:|---|---|
| 1 | `POST /api/requests` | `creatorProfileId` UUID; `requestedTitle` không rỗng ≤220; `description` không rỗng ≤5.000; `requestFee` tùy chọn ≥0; `currency` tùy chọn 3 chữ cái |
| 2 | `GET /api/requests/me` | Response có `requestId`, `status` |
| 3 | `GET /api/requests/{requestId}/milestones` | Sau khi Creator accept, lấy `milestoneId`, `status`, `amount`, `paymentId` |
| 4 | `GET /api/milestones/{milestoneId}/submissions` | Xem bản bàn giao |
| 5a | `POST /api/listener/milestones/{milestoneId}/approve` | Không body; tạo `Payment PENDING`, chưa xác nhận đã thanh toán |
| 5b | `POST /api/listener/milestones/{milestoneId}/revision` | `{"reason":"Cần chỉnh lời dẫn"}` không rỗng ≤5.000 |
| Tranh chấp mốc | `POST /api/milestones/{milestoneId}/disputes` | `{reason}` không rỗng ≤5.000 |

```json
{"creatorProfileId":"<UUID kênh>","requestedTitle":"Podcast lịch sử địa phương","description":"Yêu cầu nội dung và thời lượng","requestFee":0,"currency":"VND"}
```

Người tham gia hợp đồng còn có `POST /api/contracts/{contractId}/disputes` body `{note}` và `GET /api/me/disputes?page=0&size=20`.

### 6.2 Yêu cầu đơn giản

`POST /api/creators/{creatorId}/series-requests` body `{"requestedTitle":"...","description":"..."}`; hai chuỗi không rỗng, tối đa 220 và 10.000. `GET /api/me/series-requests` đọc danh sách; `PUT /api/me/series-requests/{requestId}` gửi lại cả hai field hoặc `DELETE` để hủy khi Creator chưa phản hồi. Khi `MEMBERSHIPS_ENABLED=false`, không cần membership để gửi yêu cầu này.

## 7. Gói thành viên và lỗi thường gặp

Gói membership mặc định bật (`MEMBERSHIPS_ENABLED=true`):
- `GET /api/creators/{creatorId}/membership-plans`: Lấy gói hội viên đang `ACTIVE` của Creator để hiển thị nút đăng ký trên trang kênh.
- `POST /api/me/subscriptions` với body `{"membershipPlanId": "<UUID>", "paymentMethod": "SEPAY" | "WALLET"}`:
  - **SEPAY**: Trả về `paymentId`, `paymentCode`, `qrImageUrl` với trạng thái `PENDING`. Frontend polling `GET /api/me/payments/{paymentId}` định kỳ đến khi `PAID` và `subscriptionStatus = ACTIVE`.
  - **WALLET**: Trừ trực tiếp số dư ví khả dụng (`GET /api/listener/wallet`). Nếu thành công chuyển ngay sang `ACTIVE`; nếu số dư ví không đủ, backend trả về lỗi `409 Conflict`.
- `GET /api/me/subscriptions`: Danh sách các gói hội viên đã đăng ký. Khi `status = ACTIVE`, Listener được mở khóa các tập podcast `MEMBERS_ONLY`.

| HTTP | Cách xử lý |
|---:|---|
| 400 | Kiểm tra field/enum/UUID và body JSON |
| 401 | Refresh token một lần, thay cả hai token; nếu lỗi thì login lại |
| 403 | Kiểm tra quyền nội dung và role |
| 404 | ID sai, tài nguyên không còn, hoặc không thuộc quyền truy cập |
| 409 | Trạng thái đã đổi, vote/request trùng hoặc chức năng gói đang tắt; tải lại dữ liệu |

Backend trả DTO, `List` hoặc `Page` trực tiếp; không có lớp bao `success/data` mặc định. Swagger của backend đang chạy: `/swagger-ui/index.html`.
