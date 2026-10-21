# Luồng upload podcast mới cho Content Creator

Tài liệu này mô tả contract hiện tại của backend cho màn hình tạo podcast của Content Creator (CC). Luồng dùng một bản ghi podcast nháp, sau đó gắn ảnh bìa, gắn audio/video, tùy chọn thêm series và nguồn tham khảo, rồi gửi duyệt.

## 1. Quyền và URL

Tất cả API dưới đây, trừ `GET /api/categories`, cần:

```http
Authorization: Bearer <accessToken>
Accept: application/json
```

Tài khoản phải thỏa cả ba điều kiện:

- role là `CREATOR`;
- tài khoản đang hoạt động;
- hồ sơ Creator đã được Admin duyệt (`APPROVED`).

Không thêm `/api` vào `BASE_URL`:

| Môi trường | `BASE_URL` |
|---|---|
| Backend local | `http://localhost:8081` |
| Android emulator | `http://10.0.2.2:8081` |
| Public qua ngrok | `https://bullpen-viewer-overfill.ngrok-free.dev` |

Ví dụ URL đầy đủ:

```text
https://bullpen-viewer-overfill.ngrok-free.dev/api/creator/podcasts
```

Khi gọi qua ngrok có thể thêm header `ngrok-skip-browser-warning: 1`. Header này không thay thế `Authorization`.

## 2. Thứ tự gọi API

```text
1. POST /api/auth/login
2. GET  /api/categories
3. GET  /api/creator/series                         (nếu cần chọn series)
4. POST /api/creator/podcasts                        tạo podcast DRAFT
5. POST /api/creator/podcasts/{podcastId}/thumbnail  upload ảnh bìa, tùy chọn
6. PUT  /api/creator/podcasts/{podcastId}/series     gắn series, tùy chọn
7. POST /api/creator/podcasts/{podcastId}/video      upload audio hoặc video, bắt buộc
8. POST /api/creator/podcasts/{podcastId}/references thêm nguồn, tùy chọn
9. POST /api/creator/podcasts/{podcastId}/references/{referenceId}/file
                                                       upload PDF nguồn, tùy chọn
10. GET /api/creator/podcasts/{podcastId}             kiểm tra dữ liệu đã gắn
11. POST /api/creator/podcasts/{podcastId}/submit    gửi Admin duyệt
```

`podcastId` luôn phải lấy từ response của bước 4. Frontend không tự sinh hoặc thay đổi UUID này.

## 3. Đăng nhập và lấy category

### 3.1 Đăng nhập

```http
POST /api/auth/login
Content-Type: application/json
```

Body:

| Field | Kiểu | Bắt buộc | Dữ liệu nhập |
|---|---|---:|---|
| `identifier` | string | Có | Username hoặc email |
| `password` | string | Có | Mật khẩu |

```json
{
  "identifier": "creator@example.com",
  "password": "your-password"
}
```

Lưu `accessToken` để gắn vào các request sau. Khi token hết hạn, dùng refresh token hoặc đăng nhập lại.

### 3.2 Category

```http
GET /api/categories
```

Chọn category trên giao diện bằng `name`, nhưng body tạo podcast phải gửi `categoryId`:

```json
{
  "categoryId": "63b13c9c-1767-44ae-8df4-5b951e4d2a18",
  "name": "Cách mạng tháng Tám 1945"
}
```

Không gửi tên category thay cho UUID.

## 4. Tạo podcast nháp

```http
POST /api/creator/podcasts
Authorization: Bearer <accessToken>
Content-Type: application/json
```

### 4.1 Body `PodcastWrite`

| Field | Kiểu JSON | Bắt buộc | Quy tắc và cách nhập |
|---|---|---:|---|
| `categoryId` | UUID string | Có | UUID từ `GET /api/categories`; category phải đang hoạt động |
| `title` | string | Có | Tên podcast, không rỗng, tối đa 220 ký tự |
| `description` | string/null | Không | Mô tả, tối đa 10.000 ký tự |
| `thumbnailUrl` | string/null | Không | URL ảnh bìa có sẵn, tối đa 2.000 ký tự; nếu chọn ảnh từ máy thì bỏ qua field này và dùng API thumbnail ở bước 5 |
| `durationSeconds` | integer | Có | Thời lượng audio/video tính bằng giây, từ 1 đến 86.400; frontend nên lấy từ metadata file |
| `episodeNumber` | integer/null | Không | Số tập, nếu gửi thì phải từ 1 trở lên |
| `visibility` | enum | Nên dùng | `PUBLIC` hoặc `MEMBERS_ONLY` |
| `exclusive` | boolean/null | Tương thích cũ | `false` tương đương `PUBLIC`, `true` tương đương `MEMBERS_ONLY`; không gửi giá trị mâu thuẫn với `visibility` |

Frontend nên dùng `visibility` và không gửi `exclusive`. Tuy nhiên phải gửi ít nhất một trong hai field `visibility` hoặc `exclusive`.

Body tối thiểu:

```json
{
  "categoryId": "63b13c9c-1767-44ae-8df4-5b951e4d2a18",
  "title": "Kháng chiến năm 1945",
  "durationSeconds": 120,
  "visibility": "PUBLIC"
}
```

Body đầy đủ:

```json
{
  "categoryId": "63b13c9c-1767-44ae-8df4-5b951e4d2a18",
  "title": "Kháng chiến năm 1945",
  "description": "Tổng hợp diễn biến lịch sử năm 1945.",
  "durationSeconds": 120,
  "episodeNumber": 1,
  "visibility": "PUBLIC"
}
```

Response thành công là `201 Created`. Podcast lúc này chưa có audio/video và có trạng thái `DRAFT`:

```json
{
  "podcastId": "09bd7a4d-74bd-4d9a-88dd-ca9fbaa328fc",
  "seriesId": null,
  "seriesTitle": null,
  "categoryId": "63b13c9c-1767-44ae-8df4-5b951e4d2a18",
  "categoryName": "Cách mạng tháng Tám 1945",
  "title": "Kháng chiến năm 1945",
  "description": "Tổng hợp diễn biến lịch sử năm 1945.",
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
  "createdAt": "2026-10-21T10:18:11.875618Z",
  "updatedAt": "2026-10-21T10:18:11.875618Z"
}
```

### 4.2 Ý nghĩa các field response

| Field | Ý nghĩa |
|---|---|
| `podcastId` | ID dùng cho mọi API upload/cập nhật tiếp theo |
| `seriesId`, `seriesTitle` | Series đang gắn; ban đầu có thể là `null` |
| `mediaKey` | Object key nội bộ trong R2; chỉ đọc, không tự sửa |
| `mediaType` | MIME type media, ví dụ `audio/mpeg` hoặc `video/webm` |
| `videoUrl` | Signed URL để xem/nghe khi gọi API detail; có thể `null` khi chưa có media |
| `videoUrlExpiresAt` | Thời điểm hết hạn của signed URL |
| `thumbnailUrl` | URL hoặc object key ảnh bìa đã lưu |
| `exclusive`/`visibility` | Quyền truy cập nội dung |
| `status` | Trạng thái workflow của podcast |

## 5. Upload ảnh bìa

Ảnh bìa được dùng chung cho podcast audio và video. Sau khi có `podcastId`, gọi:

```http
POST /api/creator/podcasts/{podcastId}/thumbnail
Authorization: Bearer <accessToken>
Content-Type: multipart/form-data
```

Multipart bắt buộc:

| Part | Kiểu | Bắt buộc | Dữ liệu |
|---|---|---:|---|
| `file` | file | Có | File ảnh thật; tên part phải đúng là `file` |

Định dạng ảnh được nhận: JPEG/JPG, PNG, WebP, GIF, AVIF, HEIC/HEIF. Backend kiểm tra cả MIME type và chữ ký file; đổi đuôi giả không được chấp nhận.

Response là `PodcastItem` đã cập nhật, trong đó `thumbnailUrl` có giá trị. Không gửi ảnh vào endpoint `/video`.

Ví dụ curl:

```bash
curl -X POST "$BASE_URL/api/creator/podcasts/$PODCAST_ID/thumbnail" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -F "file=@cover.jpg;type=image/jpeg"
```

Nếu frontend có sẵn URL ảnh hợp lệ, có thể điền `thumbnailUrl` ngay ở bước tạo/cập nhật draft và không cần gọi endpoint này.

## 6. Gắn hoặc bỏ series (tùy chọn)

Lấy series hiện có:

```http
GET /api/creator/series
```

Gắn podcast vào series:

```http
PUT /api/creator/podcasts/{podcastId}/series
Content-Type: application/json
```

```json
{
  "seriesId": "UUID_SERIES"
}
```

`seriesId` phải thuộc cùng kênh Creator. Podcast không bắt buộc có series.

Gỡ series:

```http
DELETE /api/creator/podcasts/{podcastId}/series
```

## 7. Upload audio hoặc video

Đây là API dùng chung cho cả audio và video, dù path có tên `/video`:

```http
POST /api/creator/podcasts/{podcastId}/video
Authorization: Bearer <accessToken>
Content-Type: multipart/form-data
```

Multipart bắt buộc:

| Part | Kiểu | Bắt buộc | Dữ liệu |
|---|---|---:|---|
| `file` | file | Có | Một file audio hoặc video thật |

Không gửi JSON body và không đổi tên part thành `audio`, `video`, `media` hoặc `videoFile`.

Các loại phổ biến được hỗ trợ:

| Nhóm | MIME/đuôi ví dụ |
|---|---|
| Video | `video/mp4` `.mp4`, `video/webm` `.webm`, `video/quicktime` `.mov`, `video/x-matroska` `.mkv`, `video/x-msvideo` `.avi` |
| Audio | `audio/mpeg` `.mp3`, `audio/mp4` `.m4a`, `audio/aac` `.aac`, `audio/wav` `.wav`, `audio/ogg`/`audio/opus`, `audio/flac` `.flac` |

Giới hạn request mặc định của backend là 100 MB, có thể thay đổi theo cấu hình triển khai và proxy/ngrok.

Ví dụ curl:

```bash
curl -X POST "$BASE_URL/api/creator/podcasts/$PODCAST_ID/video" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -F "file=@episode.webm;type=video/webm"
```

Response thành công là `201 Created`:

```json
{
  "podcastId": "09bd7a4d-74bd-4d9a-88dd-ca9fbaa328fc",
  "podcastTitle": "Kháng chiến năm 1945",
  "status": "DRAFT",
  "media": {
    "objectKey": "podcast-history/USER_ID/podcasts/PODCAST_ID/6149946f-8c90-47cf-947b-e0e9c7a3cf1b.webm",
    "bucket": "podcast-history",
    "publicUrl": null,
    "contentType": "video/webm",
    "bytes": 12345678
  }
}
```

`objectKey` do backend lưu vào `mediaKey`; frontend không cần ghi lại object key. `publicUrl` của audio/video thường là `null` vì file nằm trong bucket private. Muốn xem/nghe, gọi `GET /api/creator/podcasts/{podcastId}` để nhận `videoUrl` có chữ ký và thời hạn.

Nếu upload lại media khi podcast còn cho phép sửa, backend thay `mediaKey` và tạo transcript tương ứng với file mới. Frontend không cần xóa transcript cũ bằng tay; chỉ sử dụng bản ghi hiện tại trả về cho media mới.

## 8. Transcript và AI sau khi upload media

Đây là xử lý nền, frontend không cần gọi thêm API Whisper:

1. Upload audio/video thành công thì backend tạo transcript cho đúng `mediaKey` với trạng thái `PENDING`.
2. Backend gửi signed URL của object R2 cho Whisper; transcript chuyển sang `PROCESSING` rồi `COMPLETED` hoặc `FAILED`.
3. Khi transcript `COMPLETED`, backend lưu `fullText`, `segments`, `language` và `modelName`.
4. Nếu frontend gọi submit trong lúc transcript còn `PENDING`/`PROCESSING`, podcast vẫn được nhận ở `PENDING_REVIEW`; AI sẽ chờ transcript hoàn tất.
5. Gemini chỉ phân tích tiêu đề, mô tả và transcript có timestamp. AI hiện chưa phân tích hình ảnh trong video, chữ trên màn hình hoặc âm thanh không phải lời nói.

`POST /api/creator/podcasts/{podcastId}/submit` không trả transcript và không chờ Whisper/Gemini hoàn tất. Vì vậy frontend không nên coi `HTTP 200` của submit là AI đã có kết quả.

Transcript và feedback AI hiện được cung cấp cho Admin/Staff:

```http
GET  /api/admin/podcasts/{podcastId}/transcript
GET  /api/admin/podcasts/{podcastId}/ai-moderation?page=0&size=20
POST /api/admin/podcasts/{podcastId}/transcript
POST /api/admin/podcasts/{podcastId}/ai-moderation
```

Hai path `/api/staff/...` tương đương `/api/admin/...` nếu tài khoản là Staff/Admin. Trạng thái transcript:

| Status | Ý nghĩa |
|---|---|
| `PENDING` | Đã tạo bản ghi, đang chờ worker |
| `PROCESSING` | Whisper đang tải và phiên âm |
| `COMPLETED` | Có `fullText` và `segments` |
| `FAILED` | Whisper hoặc bước lưu kết quả lỗi; cần retry |

## 9. Nguồn tham khảo và PDF (tùy chọn)

Tạo metadata nguồn:

```http
POST /api/creator/podcasts/{podcastId}/references
Content-Type: application/json
```

| Field | Kiểu | Bắt buộc | Quy tắc |
|---|---|---:|---|
| `referenceType` | enum | Có | Giá trị enum đang có trong backend, ví dụ `BOOK`, `ARTICLE`, `WEBSITE`, `PDF`, `OTHER` |
| `title` | string | Có | Không rỗng, tối đa 300 ký tự |
| `author` | string/null | Không | Tối đa 200 ký tự |
| `publisher` | string/null | Không | Tối đa 200 ký tự |
| `publishedYear` | integer/null | Không | Từ 1 đến 9.999 |
| `url` | string/null | Không | Nếu gửi phải bắt đầu bằng `http://` hoặc `https://` |
| `citationText` | string/null | Không | Tối đa 10.000 ký tự |

```json
{
  "referenceType": "ARTICLE",
  "title": "Nguồn tham khảo lịch sử",
  "author": "Nguyễn Văn A",
  "publisher": "Nhà xuất bản",
  "publishedYear": 2024,
  "url": "https://example.com/article",
  "citationText": "Thông tin trích dẫn"
}
```

Lưu `referenceId` từ response rồi upload PDF:

```http
POST /api/creator/podcasts/{podcastId}/references/{referenceId}/file
Content-Type: multipart/form-data
```

Part bắt buộc là `file`, nội dung phải là PDF thật và đuôi file phải là `.pdf`. Các API quản lý metadata/file:

```text
GET    /api/creator/podcasts/{podcastId}/references
GET    /api/creator/podcasts/{podcastId}/references/{referenceId}
PUT    /api/creator/podcasts/{podcastId}/references/{referenceId}
DELETE /api/creator/podcasts/{podcastId}/references/{referenceId}
GET    /api/creator/podcasts/{podcastId}/references/{referenceId}/file
DELETE /api/creator/podcasts/{podcastId}/references/{referenceId}/file
```

## 10. Kiểm tra và submit

### 10.1 Kiểm tra draft

```http
GET /api/creator/podcasts/{podcastId}
```

Trước khi submit, frontend cần kiểm tra:

- `status` là `DRAFT` hoặc `REJECTED`;
- `mediaKey` có giá trị;
- `mediaType` bắt đầu bằng `audio/` hoặc `video/`;
- `durationSeconds` lớn hơn 0;
- `categoryId`, `title` và quyền `visibility` đúng;
- `thumbnailUrl` đã có nếu UI yêu cầu ảnh bìa.

### 10.2 Gửi Admin duyệt

```http
POST /api/creator/podcasts/{podcastId}/submit
Authorization: Bearer <accessToken>
```

Request không có body. Thành công trả `PodcastItem` với `status: "PENDING_REVIEW"`. Backend đồng thời tạo bản ghi AI ở trạng thái `PENDING` và xử lý nền.

Nếu chưa upload media hoặc `durationSeconds <= 0`, API trả lỗi và không được gọi lại submit cho đến khi sửa xong.

## 11. Ví dụ Dart tối giản

Tạo draft:

```dart
final draft = await api.post(
  '/api/creator/podcasts',
  body: {
    'categoryId': selectedCategoryId,
    'title': titleController.text.trim(),
    'description': descriptionController.text.trim(),
    'durationSeconds': duration.inSeconds,
    'episodeNumber': episodeNumber,
    'visibility': isMembersOnly ? 'MEMBERS_ONLY' : 'PUBLIC',
  },
);

final podcastId = draft['podcastId'] as String;
```

Upload multipart phải giữ đúng tên part `file`; không tự đặt header `Content-Type: multipart/form-data` khi dùng `http.MultipartRequest` vì thư viện phải tự thêm boundary:

```dart
final request = http.MultipartRequest(
  'POST',
  Uri.parse('$baseUrl/api/creator/podcasts/$podcastId/video'),
)
  ..headers['Authorization'] = 'Bearer $accessToken'
  ..headers['Accept'] = 'application/json'
  ..headers['ngrok-skip-browser-warning'] = '1';

request.files.add(http.MultipartFile.fromBytes(
  'file',
  mediaBytes,
  filename: mediaFilename,
  contentType: MediaType('video', 'webm'),
));

final response = await http.Response.fromStream(await request.send());
if (response.statusCode < 200 || response.statusCode >= 300) {
  throw Exception('Upload media thất bại: ${response.body}');
}
```

Sau khi upload thành công, frontend có thể kiểm tra detail rồi submit:

```dart
final detail = await api.get('/api/creator/podcasts/$podcastId');
final mediaType = detail['mediaType']?.toString() ?? '';
if (!mediaType.startsWith('audio/') && !mediaType.startsWith('video/')) {
  throw Exception('Podcast chưa có audio/video hợp lệ');
}

await api.post('/api/creator/podcasts/$podcastId/submit');
```

## 12. Trạng thái và lỗi frontend cần xử lý

| HTTP | Nguyên nhân thường gặp | Cách xử lý |
|---:|---|---|
| `400` | Body thiếu field, UUID sai, visibility mâu thuẫn hoặc file không đúng định dạng | Hiển thị lỗi theo field, cho nhập lại |
| `401` | JWT thiếu/hết hạn | Refresh token hoặc đăng nhập lại |
| `403` | Không phải Creator, profile chưa `APPROVED`, hoặc không sở hữu podcast | Hiển thị lỗi quyền |
| `404` | Sai category, podcast, series hoặc reference ID | Tải lại dữ liệu và dùng ID từ response |
| `409` | Podcast không còn ở `DRAFT`/`REJECTED`, series đã lưu trữ, hoặc trạng thái không cho sửa | Khóa thao tác upload/sửa theo `status` |
| `413` | File vượt giới hạn 100 MB hoặc giới hạn proxy | Cho chọn file nhỏ hơn |
| `5xx` | R2, Whisper, Gemini, backend hoặc ngrok lỗi | Giữ dữ liệu form và cho phép retry |

Trạng thái podcast cần hiển thị:

| Status | Ý nghĩa |
|---|---|
| `DRAFT` | Đang soạn, còn được sửa/upload |
| `PENDING_REVIEW` | Đã gửi Admin; không upload lại cho đến khi có kết quả |
| `APPROVED`/`PUBLISHED` | Đã được duyệt/phát hành |
| `REJECTED` | Bị từ chối; có thể sửa, upload lại và submit lại |
| `DELETED` | Đã lưu trữ/xóa khỏi workflow |

## 13. Checklist trước khi bàn giao frontend

- [ ] Lưu `accessToken` sau login và gửi Bearer token ở mọi API private.
- [ ] Dùng `categoryId` và `seriesId` lấy từ response backend.
- [ ] Tạo draft trước, lấy đúng `podcastId`.
- [ ] Nếu upload ảnh từ máy, gọi `/thumbnail` với multipart part tên `file`.
- [ ] Upload audio/video bằng `/video` với multipart part tên `file`.
- [ ] Không ghi `objectKey` trực tiếp vào body hoặc tự sửa `mediaKey`.
- [ ] Gọi submit sau khi upload media trả HTTP 2xx.
- [ ] Hiển thị `PENDING_REVIEW` ngay sau submit; AI/transcript chạy bất đồng bộ.
- [ ] Không coi response submit là kết quả AI cuối cùng.
- [ ] Khi dùng `MultipartRequest`, không tự đặt Content-Type để tránh thiếu boundary.
