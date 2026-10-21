# Hướng dẫn FE gọi API tạo và upload podcast cho Content Creator

Tài liệu này mô tả luồng Flutter gọi backend để Content Creator tạo podcast, upload video và gửi Admin duyệt.

## 1. Base URL và quyền truy cập



Backend qua ngrok:

```text
https://bullpen-viewer-overfill.ngrok-free.dev
```

Các API có tiền tố `/api/creator/**` yêu cầu:

```http
Authorization: Bearer <access_token>
```

Tài khoản phải có role `CREATOR` và hồ sơ Creator ở trạng thái `APPROVED`.

Nếu gọi qua ngrok từ Flutter Web, thêm header sau vào request:

```http
ngrok-skip-browser-warning: 1
```

Không tự đặt `Content-Type: multipart/form-data` khi upload file. `MultipartRequest` phải tự tạo boundary cho request.

## 2. Luồng gọi API

```text
GET  /api/categories
GET  /api/creator/series                 (nếu cần chọn series)
POST /api/creator/podcasts                tạo podcast DRAFT
PUT  /api/creator/podcasts/{id}/series    (tùy chọn)
POST /api/creator/podcasts/{id}/video     upload video, bắt buộc
POST /api/creator/podcasts/{id}/references (tùy chọn nguồn)
POST /api/creator/podcasts/{id}/references/{referenceId}/file (tùy chọn PDF)
POST /api/creator/podcasts/{id}/submit    gửi Admin duyệt
```

Podcast có thể tạo không cần series. Video phải upload thành công trước khi gọi `/submit`.

## 3. Lấy category

```http
GET /api/categories
```

API public, không cần JWT. Lấy `categoryId` từ response để gửi ở bước tạo podcast.

## 4. Lấy series của Creator

```http
GET /api/creator/series
```

Response trả `seriesId`. Nếu Creator không chọn series thì bỏ qua bước này.

## 5. Tạo podcast nháp

```http
POST /api/creator/podcasts
Content-Type: application/json
```

Body:

```json
{
  "categoryId": "UUID_CATEGORY",
  "title": "Lịch sử Việt Nam",
  "description": "Nội dung giới thiệu podcast",
  "thumbnailUrl": "https://example.com/thumbnail.jpg",
  "durationSeconds": 1800,
  "episodeNumber": 1,
  "visibility": "PUBLIC"
}
```

Quy tắc body:

- `categoryId`: bắt buộc.
- `title`: bắt buộc, tối đa 220 ký tự.
- `durationSeconds`: bắt buộc, từ `1` đến `86400`.
- `visibility`: `PUBLIC` hoặc `MEMBERS_ONLY`.
- Phải gửi `visibility` hoặc trường tương thích cũ `exclusive`.
- `episodeNumber`, `description`, `thumbnailUrl` là tùy chọn.

Response: `201 Created`, podcast có trạng thái `DRAFT`.

Ví dụ với `ApiClient`:

```dart
final podcast = await apiClient.post(
  '/api/creator/podcasts',
  body: {
    'categoryId': categoryId,
    'title': title,
    'description': description,
    'thumbnailUrl': thumbnailUrl,
    'durationSeconds': duration.inSeconds,
    'episodeNumber': episodeNumber,
    'visibility': isExclusive ? 'MEMBERS_ONLY' : 'PUBLIC',
  },
  headers: {
    // Chỉ cần khi base URL là ngrok và gọi từ Flutter Web.
    'ngrok-skip-browser-warning': '1',
  },
);

final podcastId = podcast['podcastId'] as String;
```

## 6. Gắn vào series

```http
PUT /api/creator/podcasts/{podcastId}/series
Content-Type: application/json
```

Body:

```json
{
  "seriesId": "UUID_SERIES"
}
```

Nếu muốn gỡ series:

```http
DELETE /api/creator/podcasts/{podcastId}/series
```

## 7. Upload video

```http
POST /api/creator/podcasts/{podcastId}/video
Content-Type: multipart/form-data
```

Tên field bắt buộc là `file`.

### Cách gọi qua `http.MultipartRequest`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

Future<Map<String, dynamic>> uploadPodcastVideo({
  required String baseUrl,
  required String accessToken,
  required String podcastId,
  required List<int> bytes,
  required String filename,
  String mimeType = 'video/mp4',
}) async {
  final uri = Uri.parse(
    '$baseUrl/api/creator/podcasts/$podcastId/video',
  );
  final request = http.MultipartRequest('POST', uri)
    ..headers['Authorization'] = 'Bearer $accessToken'
    ..headers['Accept'] = 'application/json'
    // Giữ header này khi baseUrl là ngrok.
    ..headers['ngrok-skip-browser-warning'] = '1';

  final mimeParts = mimeType.split('/');
  request.files.add(
    http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType(mimeParts[0], mimeParts[1]),
    ),
  );

  final streamed = await request.send();
  final response = await http.Response.fromStream(streamed);
  final body = response.body.isEmpty ? null : jsonDecode(response.body);

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Upload video thất bại: ${response.statusCode} $body');
  }
  return Map<String, dynamic>.from(body as Map);
}
```

Response upload gồm các trường chính:

```json
{
  "podcastId": "UUID_PODCAST",
  "podcastTitle": "Lịch sử Việt Nam",
  "status": "DRAFT",
  "media": {
    "objectKey": "podcasts/UUID/video.mp4",
    "bucket": "podcast-history",
    "publicUrl": null,
    "contentType": "video/mp4",
    "bytes": 12345678
  }
}
```

`objectKey` do backend quản lý. FE không cần tự ghi key vào database.

## 8. Thêm nguồn tham khảo

```http
POST /api/creator/podcasts/{podcastId}/references
Content-Type: application/json
```

Body:

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

`referenceType` nhận một trong các giá trị:

```text
BOOK, ARTICLE, WEBSITE, PDF, OTHER
```

Upload PDF cho nguồn đã tạo:

```http
POST /api/creator/podcasts/{podcastId}/references/{referenceId}/file
Content-Type: multipart/form-data
```

Tên field file vẫn là `file`.

## 9. Kiểm tra podcast

```http
GET /api/creator/podcasts/{podcastId}
```

API này trả thông tin podcast và URL video có thời hạn nếu video đã upload.

## 10. Gửi Admin duyệt

```http
POST /api/creator/podcasts/{podcastId}/submit
```

Không cần body.

Điều kiện:

- Podcast thuộc Creator hiện tại.
- Podcast có video hợp lệ.
- `durationSeconds` lớn hơn `0`.

Nếu thành công, trạng thái chuyển thành:

```text
PENDING_REVIEW
```

## 11. API hỗ trợ màn hình Creator Studio

Danh sách podcast:

```http
GET /api/creator/podcasts
```

Dashboard tổng hợp:

```http
GET /api/creator/dashboard?period=7d
```

Lịch sử duyệt podcast:

```http
GET /api/creator/podcasts/{podcastId}/reviews?page=0&size=20
```

Gửi khiếu nại nếu podcast bị từ chối hoặc ẩn:

```http
POST /api/creator/podcasts/{podcastId}/appeals
Content-Type: application/json
```

Body:

```json
{
  "note": "Lý do đề nghị xem xét lại"
}
```

## 12. Mã lỗi thường gặp

| HTTP | Nguyên nhân |
|---|---|
| `400` | Body thiếu field, `visibility` không hợp lệ hoặc file không đúng định dạng |
| `401` | Thiếu JWT, JWT hết hạn hoặc token bị thu hồi |
| `403` | Không phải role `CREATOR` hoặc hồ sơ Creator chưa được duyệt |
| `404` | Không tìm thấy category, series hoặc podcast |
| `409` | Podcast đang ở trạng thái không cho phép chỉnh sửa/gửi duyệt |
| `413` | File video vượt giới hạn upload của backend |

