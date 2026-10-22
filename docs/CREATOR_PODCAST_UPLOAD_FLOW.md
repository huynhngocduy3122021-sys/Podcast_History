# Hướng dẫn upload podcast cho Content Creator

Tài liệu này mô tả đúng contract hiện tại của backend và thứ tự gọi API từ lúc đăng nhập đến lúc gửi podcast đi duyệt. Frontend chỉ gọi API Creator; frontend **không gọi trực tiếp Whisper hoặc Gemini**.

## 1. Thông tin kết nối

`BASE_URL` không bao gồm `/api`.

| Môi trường | BASE_URL |
|---|---|
| Backend local | `http://localhost:8081` |
| Android Emulator | `http://10.0.2.2:8081` |
| Public qua ngrok | `https://bullpen-viewer-overfill.ngrok-free.dev` |

URL đầy đủ, ví dụ:

```text
https://bullpen-viewer-overfill.ngrok-free.dev/api/creator/podcasts
```

Các request cần đăng nhập dùng:

```http
Authorization: Bearer <accessToken>
Accept: application/json
```

Nếu gọi qua ngrok, có thể thêm:

```http
ngrok-skip-browser-warning: 1
```

Header này chỉ bỏ trang cảnh báo của ngrok, không thay thế token.

Tài khoản phải có role `CREATOR`, đang hoạt động và hồ sơ Creator có `verificationStatus = APPROVED`.

## 2. Thứ tự gọi API bắt buộc

```text
1. POST /api/auth/login
2. GET  /api/categories
3. GET  /api/creator/series                         (nếu cho chọn series)
4. POST /api/creator/podcasts                       tạo bản nháp
5. POST /api/creator/podcasts/{podcastId}/thumbnail (tùy chọn)
6. PUT  /api/creator/podcasts/{podcastId}/series    (tùy chọn)
7. POST /api/creator/podcasts/{podcastId}/video     upload audio/video, bắt buộc
8. POST /api/creator/podcasts/{podcastId}/references (tùy chọn)
9. POST /api/creator/podcasts/{podcastId}/references/{referenceId}/file (tùy chọn)
10. GET /api/creator/podcasts/{podcastId}            kiểm tra dữ liệu
11. POST /api/creator/podcasts/{podcastId}/submit   gửi duyệt
```

`podcastId` phải lấy từ response của bước 4. Không tự tạo UUID mới cho các bước sau.

Ảnh bìa và media có thể upload theo thứ tự 5–7. Riêng bước 7 bắt buộc trước khi submit. Bước 8–9 chỉ dùng khi podcast có nguồn tham khảo/PDF.

## 3. Bước 1 — Đăng nhập

### Request

```http
POST {BASE_URL}/api/auth/login
Content-Type: application/json
```

| Field | Kiểu | Bắt buộc | Nội dung |
|---|---|---:|---|
| `identifier` | string | Có | Username hoặc email |
| `password` | string | Có | Mật khẩu, tối đa 72 ký tự |

```json
{
  "identifier": "creator@example.com",
  "password": "your-password"
}
```

### Response cần lưu

```json
{
  "accessToken": "eyJ...",
  "refreshToken": "...",
  "tokenType": "Bearer",
  "expiresIn": 600,
  "refreshExpiresIn": 604800,
  "user": {
    "id": "3f32b5af-c057-40c9-89a6-2080349b0643",
    "username": "creator01",
    "email": "creator@example.com",
    "displayName": "Creator",
    "role": "CREATOR"
  }
}
```

Frontend lưu `accessToken` và gửi nó trong mọi request riêng tư tiếp theo.

## 4. Bước 2 — Lấy danh mục

```http
GET {BASE_URL}/api/categories
Accept: application/json
```

Đây là API public. Hiển thị danh sách cho Creator chọn và gửi **`categoryId`** vào bước tạo podcast. Không gửi tên danh mục thay cho UUID.

## 5. Bước 3 — Lấy series (tùy chọn)

```http
GET {BASE_URL}/api/creator/series
Authorization: Bearer <accessToken>
Accept: application/json
```

Nếu người dùng chọn series, lưu `seriesId` rồi gọi API gắn series sau khi tạo podcast. Podcast vẫn tạo được mà chưa có series.

## 6. Bước 4 — Tạo podcast nháp

### Request

```http
POST {BASE_URL}/api/creator/podcasts
Authorization: Bearer <accessToken>
Content-Type: application/json
Accept: application/json
```

### Body và quy tắc dữ liệu

| Field | Kiểu | Bắt buộc | Quy tắc |
|---|---|---:|---|
| `categoryId` | UUID string | Có | ID danh mục đang hoạt động từ `/api/categories` |
| `title` | string | Có | Không rỗng, tối đa 220 ký tự |
| `description` | string/null | Không | Tối đa 10.000 ký tự |
| `thumbnailUrl` | string/null | Không | Tối đa 2.000 ký tự; để `null` nếu sẽ upload ảnh bằng multipart |
| `durationSeconds` | integer | Có | Từ 1 đến 86.400; phải lớn hơn 0 khi submit |
| `episodeNumber` | integer/null | Không | Nếu gửi thì tối thiểu 1 |
| `visibility` | enum | Có một trong hai | `PUBLIC` hoặc `MEMBERS_ONLY` |
| `exclusive` | boolean | Có một trong hai | Tương thích client cũ: `false` = PUBLIC, `true` = MEMBERS_ONLY |

Phải gửi `visibility` hoặc `exclusive`. Nếu gửi cả hai thì chúng phải khớp. Nên dùng `visibility`, không cần gửi `exclusive`.

### Body khuyến nghị

```json
{
  "categoryId": "63b13c9c-1767-44ae-8df4-5b951e4d2a18",
  "title": "Kháng chiến năm 1945",
  "description": "Tổng hợp lịch sử Việt Nam năm 1945.",
  "thumbnailUrl": null,
  "durationSeconds": 120,
  "episodeNumber": 1,
  "visibility": "PUBLIC"
}
```

Không gửi giá trị mẫu như `"thumbnailUrl": "string"`; dùng `null` hoặc bỏ field này nếu chưa có URL ảnh.

### Response `201 Created`

```json
{
  "podcastId": "254f8e8c-51cb-4405-995f-ef063a3b825a",
  "seriesId": null,
  "seriesTitle": null,
  "categoryId": "63b13c9c-1767-44ae-8df4-5b951e4d2a18",
  "categoryName": "Cách mạng tháng Tám 1945",
  "title": "Kháng chiến năm 1945",
  "description": "Tổng hợp lịch sử Việt Nam năm 1945.",
  "mediaKey": null,
  "mediaType": null,
  "videoUrl": null,
  "videoUrlExpiresAt": null,
  "thumbnailUrl": null,
  "durationSeconds": 120,
  "episodeNumber": 1,
  "exclusive": false,
  "visibility": "PUBLIC",
  "status": "DRAFT",
  "publishedAt": null,
  "createdAt": "2026-10-22T10:00:00Z",
  "updatedAt": "2026-10-22T10:00:00Z"
}
```

Lưu `podcastId`. `mediaKey`, `mediaType` và `videoUrl` chưa có vì chưa upload media.

## 7. Bước 5 — Upload ảnh bìa (tùy chọn)

Ảnh bìa dùng cùng podcast vừa tạo; không cần tạo URL trước và không cần gọi `/api/uploads`.

```http
POST {BASE_URL}/api/creator/podcasts/{podcastId}/thumbnail
Authorization: Bearer <accessToken>
Accept: application/json
Content-Type: multipart/form-data
```

Multipart phải có đúng một part:

| Part | Kiểu | Bắt buộc | Nội dung |
|---|---|---:|---|
| `file` | file | Có | Ảnh JPEG, PNG, WebP, GIF, AVIF, HEIC hoặc HEIF |

Ví dụ `curl`:

```bash
curl -X POST "{BASE_URL}/api/creator/podcasts/{podcastId}/thumbnail" \
  -H "Authorization: Bearer <accessToken>" \
  -F "file=@cover.png"
```

Không tự đặt header `Content-Type` khi dùng `FormData` trong browser/Dart; thư viện phải tự thêm boundary.

Response là `PodcastItem` giống bước 4, trong đó `thumbnailUrl` đã được cập nhật. Nếu upload lại ảnh, ảnh mới thay ảnh cũ.

## 8. Bước 6 — Gắn series (tùy chọn)

```http
PUT {BASE_URL}/api/creator/podcasts/{podcastId}/series
Authorization: Bearer <accessToken>
Content-Type: application/json
```

Body chỉ có một field:

```json
{
  "seriesId": "a1d7f0a6-2ea7-4c50-a0e1-8b0d8e08ed11"
}
```

`seriesId` phải là series thuộc chính kênh Creator và chưa bị lưu trữ. Gỡ series bằng:

```http
DELETE {BASE_URL}/api/creator/podcasts/{podcastId}/series
```

## 9. Bước 7 — Upload audio hoặc video (bắt buộc)

Dù tên endpoint là `/video`, endpoint này nhận cả audio và video.

```http
POST {BASE_URL}/api/creator/podcasts/{podcastId}/video
Authorization: Bearer <accessToken>
Accept: application/json
Content-Type: multipart/form-data
```

Multipart:

| Part | Kiểu | Bắt buộc | Nội dung |
|---|---|---:|---|
| `file` | file | Có | Một file audio hoặc video |

Định dạng thường dùng:

- Video: `mp4`, `webm`, `mov`, `m4v`, `mkv`, `3gp`, `avi`.
- Audio: `mp3`, `m4a`, `aac`, `wav`, `ogg/oga`, `opus`, `flac`.

Giới hạn multipart mặc định là 100 MB (`spring.servlet.multipart.max-file-size` và `max-request-size`). Backend kiểm tra cả MIME type và chữ ký file, nên không chỉ đổi phần mở rộng là đủ.

Ví dụ:

```bash
curl -X POST "{BASE_URL}/api/creator/podcasts/{podcastId}/video" \
  -H "Authorization: Bearer <accessToken>" \
  -F "file=@episode.webm;type=video/webm"
```

### Response `201 Created`

```json
{
  "podcastId": "254f8e8c-51cb-4405-995f-ef063a3b825a",
  "podcastTitle": "Kháng chiến năm 1945",
  "status": "DRAFT",
  "media": {
    "objectKey": "podcast-history/<creatorId>/podcasts/<podcastId>/<fileId>.webm",
    "bucket": "<bucket-name>",
    "publicUrl": null,
    "contentType": "video/webm",
    "bytes": 12345678
  }
}
```

`objectKey` là dữ liệu nội bộ, không dùng làm `thumbnailUrl`. Sau khi upload thành công, backend tự lưu `mediaKey`/`mediaType` vào podcast và tự enqueue transcript cho đúng media.

## 10. Bước 8–9 — Nguồn tham khảo và PDF (tùy chọn)

### 10.1 Tạo metadata nguồn

```http
POST {BASE_URL}/api/creator/podcasts/{podcastId}/references
Authorization: Bearer <accessToken>
Content-Type: application/json
```

Body:

| Field | Kiểu | Bắt buộc | Quy tắc |
|---|---|---:|---|
| `referenceType` | enum | Có | `BOOK`, `ARTICLE`, `WEBSITE`, `PDF`, `OTHER` |
| `title` | string | Có | Không rỗng, tối đa 300 ký tự |
| `author` | string/null | Không | Tối đa 200 ký tự |
| `publisher` | string/null | Không | Tối đa 200 ký tự |
| `publishedYear` | integer/null | Không | Từ 1 đến 9999 |
| `url` | string/null | Không | Nếu có phải bắt đầu bằng `http://` hoặc `https://` |
| `citationText` | string/null | Không | Tối đa 10.000 ký tự |

Ví dụ:

```json
{
  "referenceType": "BOOK",
  "title": "Lịch sử Việt Nam hiện đại",
  "author": "Nguyễn Văn A",
  "publisher": "Nhà xuất bản B",
  "publishedYear": 2020,
  "url": null,
  "citationText": "Chương 4, trang 80-95"
}
```

Lấy `referenceId` từ response tạo nguồn.

### 10.2 Upload PDF cho nguồn

```http
POST {BASE_URL}/api/creator/podcasts/{podcastId}/references/{referenceId}/file
Authorization: Bearer <accessToken>
Accept: application/json
Content-Type: multipart/form-data
```

Part bắt buộc là `file`. Chỉ dùng file PDF theo nghiệp vụ nguồn tham khảo. API lấy URL tải PDF có chữ ký:

```http
GET {BASE_URL}/api/creator/podcasts/{podcastId}/references/{referenceId}/file
```

## 11. Bước 10 — Kiểm tra trước khi submit

```http
GET {BASE_URL}/api/creator/podcasts/{podcastId}
Authorization: Bearer <accessToken>
Accept: application/json
```

Frontend cần kiểm tra tối thiểu:

| Field | Điều kiện trước submit |
|---|---|
| `podcastId` | Đúng ID của bản nháp đã tạo |
| `categoryId` | Có giá trị |
| `title` | Không rỗng |
| `durationSeconds` | Lớn hơn 0 |
| `mediaKey` | Có giá trị sau upload audio/video |
| `mediaType` | Bắt đầu bằng `audio/` hoặc `video/` |
| `status` | `DRAFT` hoặc `REJECTED` |

`videoUrl` là signed URL dùng phát preview và có thể hết hạn; `mediaKey` mới là key lưu trong database. `thumbnailUrl` có thể là URL public của ảnh bìa.

## 12. Bước 11 — Submit podcast

Submit không có request body:

```http
POST {BASE_URL}/api/creator/podcasts/{podcastId}/submit
Authorization: Bearer <accessToken>
Accept: application/json
```

Backend chỉ cho submit khi đã có audio/video hợp lệ và `durationSeconds > 0`. Response trả `PodcastItem` với trạng thái ban đầu:

```json
{
  "podcastId": "254f8e8c-51cb-4405-995f-ef063a3b825a",
  "status": "PENDING_REVIEW",
  "mediaKey": "podcast-history/.../episode.webm",
  "mediaType": "video/webm"
}
```

Không gửi `podcastId` trong body. ID chỉ nằm trên URL.

## 13. Xử lý nền sau khi upload và submit

### Sau upload media

```text
Upload media thành công
        ↓
Backend tạo transcript: PENDING
        ↓
Gọi whisper-service bằng signed URL R2
        ↓
PROCESSING → COMPLETED hoặc FAILED
        ↓
Lưu fullText, segments, language, modelName
```

### Sau submit

```text
POST /submit
        ↓
Podcast = PENDING_REVIEW
        ↓
AI moderation được enqueue
        ↓
Nếu transcript chưa COMPLETED: AI chờ, chưa gửi Gemini
        ↓
Transcript COMPLETED: gửi title + description + transcript có timestamp cho Gemini
        ↓
SAFE + APPROVE: tự động APPROVED
REVIEW, REJECT hoặc FAILED: giữ PENDING_REVIEW để Admin xử lý
```

Vì đây là xử lý nền, `HTTP 200` của submit **không có nghĩa** transcript hoặc AI đã hoàn tất. Frontend không gọi Whisper/Gemini và không cần gửi lại file. Có thể gọi lại `GET /api/creator/podcasts/{podcastId}` để theo dõi trạng thái podcast.

Gemini hiện phân tích tiêu đề, mô tả và transcript có timestamp. Backend chưa phân tích hình ảnh trong video, chữ trên màn hình hoặc âm thanh không phải lời nói.

Creator không có API riêng để đọc transcript/AI moderation. Admin/Staff xem bằng:

```http
GET /api/admin/podcasts/{podcastId}/transcript
GET /api/admin/podcasts/{podcastId}/ai-moderation?page=0&size=20
GET /api/admin/podcasts/{podcastId}/reviews?page=0&size=20
```

Nếu transcript hoặc AI bị lỗi, Admin/Staff có thể retry:

```http
POST /api/admin/podcasts/{podcastId}/transcript
POST /api/admin/podcasts/{podcastId}/ai-moderation
```

Staff dùng cùng path nhưng thay `/api/admin` bằng `/api/staff` và phải có quyền tương ứng.

## 14. Ví dụ gọi tuần tự bằng JavaScript

```js
const BASE_URL = "https://bullpen-viewer-overfill.ngrok-free.dev";
const jsonHeaders = (token) => ({
  Authorization: `Bearer ${token}`,
  Accept: "application/json",
  "Content-Type": "application/json"
});

// 1. Login
const loginRes = await fetch(`${BASE_URL}/api/auth/login`, {
  method: "POST",
  headers: { Accept: "application/json", "Content-Type": "application/json" },
  body: JSON.stringify({ identifier: "creator@example.com", password: "your-password" })
});
const login = await loginRes.json();
const token = login.accessToken;

// 2. Create draft
const draftRes = await fetch(`${BASE_URL}/api/creator/podcasts`, {
  method: "POST",
  headers: jsonHeaders(token),
  body: JSON.stringify({
    categoryId: "63b13c9c-1767-44ae-8df4-5b951e4d2a18",
    title: "Kháng chiến năm 1945",
    description: "Tổng hợp lịch sử Việt Nam năm 1945.",
    thumbnailUrl: null,
    durationSeconds: 120,
    episodeNumber: 1,
    visibility: "PUBLIC"
  })
});
const draft = await draftRes.json();
const podcastId = draft.podcastId;

// 3. Upload thumbnail (optional)
const thumbnail = new FormData();
thumbnail.append("file", coverFile);
await fetch(`${BASE_URL}/api/creator/podcasts/${podcastId}/thumbnail`, {
  method: "POST",
  headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
  body: thumbnail
});

// 4. Upload audio/video (required)
const media = new FormData();
media.append("file", mediaFile);
await fetch(`${BASE_URL}/api/creator/podcasts/${podcastId}/video`, {
  method: "POST",
  headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
  body: media
});

// 5. Submit; không có body
const submitRes = await fetch(`${BASE_URL}/api/creator/podcasts/${podcastId}/submit`, {
  method: "POST",
  headers: { Authorization: `Bearer ${token}`, Accept: "application/json" }
});
const submittedPodcast = await submitRes.json();
```

Trong ví dụ trên, `coverFile` và `mediaFile` là đối tượng `File` lấy từ input file. Với Flutter/Dart, dùng `MultipartRequest`, thêm file với field name chính xác là `file`, và không đặt thủ công `Content-Type` có boundary.

## 15. Cập nhật hoặc gửi lại

Podcast ở `DRAFT` hoặc `REJECTED` có thể sửa bằng:

```http
PUT /api/creator/podcasts/{podcastId}
```

Body của `PUT` dùng toàn bộ schema `PodcastWrite` ở bước 4; không gửi body một phần. Sau khi bị `REJECTED`, Creator sửa metadata hoặc upload lại media rồi submit lại.

Podcast đang `PENDING_REVIEW` không được sửa hoặc upload lại. Podcast `APPROVED`/`PUBLISHED` khi Creator chỉnh sửa sẽ quay về `DRAFT` theo logic backend, sau đó phải submit lại.

## 16. Mã lỗi thường gặp

| HTTP | Nguyên nhân thường gặp | Cách xử lý |
|---:|---|---|
| 400 | Thiếu field, `visibility`/`exclusive` không hợp lệ, file sai chữ ký | Kiểm tra body và đúng loại file |
| 401 | Thiếu hoặc hết hạn access token | Đăng nhập/refresh token |
| 403 | Không phải Creator, tài khoản bị khóa hoặc hồ sơ chưa được duyệt | Kiểm tra role và trạng thái hồ sơ |
| 404 | Sai `podcastId`, `categoryId`, `seriesId` hoặc không thuộc kênh hiện tại | Dùng ID từ response API của chính user |
| 409 | Podcast/series đang ở trạng thái không cho sửa hoặc category/series không dùng được | Đọc message response và kiểm tra `status` |
| 413 | File vượt giới hạn 100 MB | Nén hoặc cấu hình lại giới hạn server |
| 415 | `Content-Type`/định dạng file không được hỗ trợ | Gửi multipart part tên `file` và MIME đúng |

## 17. Checklist frontend

- [ ] Login và lưu `accessToken`.
- [ ] Lấy `categoryId` từ `/api/categories`.
- [ ] Tạo draft bằng `POST /api/creator/podcasts` và lưu `podcastId`.
- [ ] Gửi `visibility` hoặc `exclusive`, không để cả hai lệch nhau.
- [ ] Upload ảnh bằng `/thumbnail`, multipart field tên `file` (nếu có ảnh).
- [ ] Upload audio/video bằng `/video`, multipart field tên `file` (bắt buộc).
- [ ] Không gọi `/api/uploads` cho luồng Creator này.
- [ ] Có thể kiểm tra `GET /api/creator/podcasts/{podcastId}` trước submit.
- [ ] Submit bằng POST không body.
- [ ] Hiển thị `PENDING_REVIEW` ngay sau submit; không báo AI hoàn tất dựa trên HTTP 200.
- [ ] Không gọi trực tiếp Whisper/Gemini từ frontend.
