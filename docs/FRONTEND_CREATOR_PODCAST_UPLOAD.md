# Hướng dẫn FE gọi API tạo và upload podcast cho Content Creator

Tài liệu này là checklist cho frontend Flutter: đăng nhập, lấy dữ liệu cho form, tạo podcast nháp, upload video hoặc audio, thêm nguồn tham khảo và gửi podcast cho Admin duyệt. Các ID phải lấy từ response backend, frontend không tự sinh UUID.

## 1. Base URL

Không thêm /api vào biến BASE_URL; các endpoint bên dưới đã có sẵn tiền tố /api.

| Môi trường | BASE_URL | Ghi chú |
|---|---|---|
| Backend local | http://localhost:8081 | Flutter Web/Desktop chạy cùng máy backend |
| Android Emulator | http://10.0.2.2:8081 | localhost của emulator không trỏ tới máy host |
| Public qua ngrok | https://bullpen-viewer-overfill.ngrok-free.dev | Cho người khác truy cập từ Internet |

Ví dụ URL đầy đủ:

~~~text
https://bullpen-viewer-overfill.ngrok-free.dev/api/creator/podcasts
~~~

## 2. Đăng nhập và quyền truy cập

Các API /api/creator/** yêu cầu:

- Header Authorization: Bearer accessToken.
- Tài khoản có role CREATOR.
- Hồ sơ Creator đã được Admin duyệt (APPROVED).

### 2.1 Đăng nhập

~~~http
POST /api/auth/login
Content-Type: application/json
~~~

| Field | Kiểu | Bắt buộc | Quy tắc |
|---|---|---:|---|
| identifier | string | Có | Username hoặc email, tối đa 255 ký tự |
| password | string | Có | Tối đa 72 ký tự |

~~~json
{
  "identifier": "creator@example.com",
  "password": "your-password"
}
~~~

Response cần lưu accessToken và refreshToken:

~~~json
{
  "accessToken": "eyJ...",
  "refreshToken": "eyJ...",
  "tokenType": "Bearer",
  "expiresIn": 3600,
  "refreshExpiresIn": 2592000,
  "user": {
    "id": "UUID_USER",
    "username": "creator",
    "email": "creator@example.com",
    "displayName": "Creator",
    "role": "CREATOR"
  }
}
~~~

User không có role CREATOR hoặc profile chưa APPROVED sẽ nhận 403.

## 3. Header và quy tắc request

Request JSON:

~~~http
Authorization: Bearer accessToken
Accept: application/json
Content-Type: application/json
~~~

Khi gọi ngrok từ Flutter Web, thêm:

~~~http
ngrok-skip-browser-warning: 1
~~~

GET /api/categories là public, không bắt buộc JWT.

Upload video/audio/PDF dùng multipart/form-data với field file tên chính xác là file. Không tự đặt Content-Type multipart/form-data; MultipartRequest phải tự tạo boundary. ApiClient.uploadMultipart có thể nhận headers tùy chỉnh; khi gọi ngrok truyền ngrok-skip-browser-warning: 1.

## 4. Thứ tự gọi API để upload hoàn chỉnh

~~~text
1. POST /api/auth/login
2. GET  /api/categories
3. GET  /api/creator/series
   hoặc POST /api/creator/series nếu tạo series mới
4. POST /api/creator/podcasts                       -> nhận podcastId
5. POST /api/creator/podcasts/{podcastId}/thumbnail -> tùy chọn, khi chọn ảnh từ máy
6. PUT  /api/creator/podcasts/{podcastId}/series    -> tùy chọn
7. POST /api/creator/podcasts/{podcastId}/video     -> upload video hoặc audio, bắt buộc
8. POST /api/creator/podcasts/{podcastId}/references -> tùy chọn
9. POST /api/creator/podcasts/{podcastId}/references/{referenceId}/file -> tùy chọn
10. GET  /api/creator/podcasts/{podcastId}           -> kiểm tra
11. POST /api/creator/podcasts/{podcastId}/submit   -> gửi Admin
~~~

Podcast được tạo ở DRAFT. Chỉ gọi bước 11 sau khi bước 7 trả HTTP 2xx; submit thành công chuyển trạng thái thành PENDING_REVIEW.

## 5. Lấy category cho form

~~~http
GET /api/categories
~~~

Response:

~~~json
[
  {
    "categoryId": "UUID_CATEGORY",
    "name": "Lịch sử",
    "slug": "lich-su",
    "description": "..."
  }
]
~~~

Hiển thị name trong dropdown nhưng gửi categoryId khi tạo podcast. Không gửi tên thay cho ID.

## 6. Series

### 6.1 Lấy series của Creator

~~~http
GET /api/creator/series
Authorization: Bearer accessToken
~~~

Frontend dùng seriesId trong response. Không chọn series thì bỏ qua bước gắn series.

### 6.2 Tạo series mới (tùy chọn)

~~~http
POST /api/creator/series
~~~

| Field | Kiểu | Bắt buộc | Quy tắc |
|---|---|---:|---|
| categoryId | UUID | Có | ID từ GET /api/categories |
| title | string | Có | Tối đa 200 ký tự |
| slug | string | Có | Tối đa 220 ký tự |
| description | string | Không | Tối đa 10.000 ký tự |
| coverUrl | string | Không | Tối đa 2.000 ký tự |

~~~json
{
  "categoryId": "UUID_CATEGORY",
  "title": "Lịch sử Việt Nam",
  "slug": "lich-su-viet-nam",
  "description": "Chuỗi podcast về lịch sử Việt Nam",
  "coverUrl": "https://example.com/cover.jpg"
}
~~~

Lưu seriesId từ response để dùng ở mục 8.

## 7. Tạo podcast nháp

~~~http
POST /api/creator/podcasts
Authorization: Bearer accessToken
Content-Type: application/json
~~~

### 7.1 Dữ liệu form cần nhập

| Field | Kiểu | Bắt buộc | Frontend nhập |
|---|---|---:|---|
| categoryId | UUID | Có | ID category được chọn |
| title | string | Có | Tên podcast, tối đa 220 ký tự |
| description | string | Không | Mô tả, tối đa 10.000 ký tự |
| thumbnailUrl | string | Không | URL ảnh, tối đa 2.000 ký tự |
| durationSeconds | integer | Có | Thời lượng media video/audio bằng giây, 1 đến 86.400 |
| episodeNumber | integer | Không | Số tập, nếu nhập thì tối thiểu 1 |
| visibility | enum | Nên dùng | PUBLIC hoặc MEMBERS_ONLY |
| exclusive | boolean | Tương thích cũ | Dùng thay visibility; không gửi giá trị mâu thuẫn |

Khuyến nghị chỉ gửi visibility: nội dung công khai dùng PUBLIC, nội dung chỉ thành viên dùng MEMBERS_ONLY. Nếu gửi cả hai, PUBLIC phải đi với false, MEMBERS_ONLY phải đi với true.

### 7.2 JSON tối thiểu

~~~json
{
  "categoryId": "UUID_CATEGORY",
  "title": "Lịch sử Việt Nam - Tập 1",
  "durationSeconds": 1800,
  "visibility": "PUBLIC"
}
~~~

### 7.3 JSON đầy đủ

~~~json
{
  "categoryId": "UUID_CATEGORY",
  "title": "Lịch sử Việt Nam - Tập 1",
  "description": "Tóm tắt nội dung tập podcast.",
  "thumbnailUrl": "https://example.com/thumbnail.jpg",
  "durationSeconds": 1800,
  "episodeNumber": 1,
  "visibility": "MEMBERS_ONLY"
}
~~~

Response là 201 Created, trạng thái ban đầu DRAFT. Lưu podcastId cho mọi request sau:

~~~json
{
  "podcastId": "UUID_PODCAST",
  "title": "Lịch sử Việt Nam - Tập 1",
  "status": "DRAFT",
  "categoryId": "UUID_CATEGORY",
  "durationSeconds": 1800,
  "visibility": "MEMBERS_ONLY"
}
~~~

Ví dụ gọi bằng ApiClient:

~~~dart
final podcast = await apiClient.post(
  '/api/creator/podcasts',
  body: {
    'categoryId': categoryId,
    'title': titleController.text.trim(),
    'description': descriptionController.text.trim(),
    'thumbnailUrl': thumbnailUrl,
    'durationSeconds': duration.inSeconds,
    'episodeNumber': episodeNumber,
    'visibility': isMembersOnly ? 'MEMBERS_ONLY' : 'PUBLIC',
  },
  headers: {
    'ngrok-skip-browser-warning': '1',
  },
);

final podcastId = podcast['podcastId'] as String;
~~~

### 7.4 Upload ảnh bìa từ máy

Sau khi tạo draft, upload ảnh bằng multipart để backend gắn ảnh trực tiếp vào podcast. Field file phải tên chính xác là `file`:

~~~http
POST /api/creator/podcasts/{podcastId}/thumbnail
Authorization: Bearer accessToken
Content-Type: multipart/form-data
~~~

~~~dart
final updated = await apiClient.uploadMultipart(
  '/api/creator/podcasts/$podcastId/thumbnail',
  fileFieldName: 'file',
  filename: imageFilename,
  fileBytes: imageBytes,
  mimeType: imageMimeType, // image/jpeg, image/png hoặc image/webp
  headers: {'ngrok-skip-browser-warning': '1'},
);
~~~

Response trả về podcast và trường `thumbnailUrl`. Ảnh này được dùng làm ảnh bìa cho cả podcast audio và video. Không gửi ảnh qua endpoint `/video`.

## 8. Sửa và gắn series

Sửa podcast trước khi submit:

~~~http
PUT /api/creator/podcasts/{podcastId}
~~~

Body dùng cùng schema PodcastWrite ở mục 7.

Gắn series:

~~~http
PUT /api/creator/podcasts/{podcastId}/series
Content-Type: application/json
~~~

~~~json
{
  "seriesId": "UUID_SERIES"
}
~~~

Gỡ series:

~~~http
DELETE /api/creator/podcasts/{podcastId}/series
~~~

Podcast không bắt buộc có series.

## 9. Upload video hoặc audio

~~~http
POST /api/creator/podcasts/{podcastId}/video
Authorization: Bearer accessToken
Content-Type: multipart/form-data
~~~

| Multipart field | Kiểu | Bắt buộc | Nội dung |
|---|---|---:|---|
| file | file | Có | File video hoặc audio từ thiết bị |

Không gửi JSON body và không đổi tên field thành video, media hoặc videoFile. Dù endpoint có tên `/video`, frontend dùng chính endpoint này cho cả video và audio.

### 9.1 Hàm Flutter upload qua ngrok

~~~dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

Future<Map<String, dynamic>> uploadPodcastMedia({
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
    ..headers['ngrok-skip-browser-warning'] = '1';

  final parts = mimeType.split('/');
  request.files.add(
    http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType(
        parts[0],
        parts.length > 1 ? parts[1] : 'octet-stream',
      ),
    ),
  );

  final streamed = await request.send();
  final response = await http.Response.fromStream(streamed);
  final decoded = response.body.isEmpty ? null : jsonDecode(response.body);

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'Upload media thất bại: ' +
      response.statusCode.toString() +
      ' ' +
      decoded.toString(),
    );
  }

  return Map<String, dynamic>.from(decoded as Map);
}
~~~

Hàm trên dùng được cho cả hai loại file. Chỉ cần truyền MIME type phù hợp, ví dụ `video/mp4`, `video/webm`, `audio/mpeg`, `audio/mp4`, `audio/wav`, `audio/ogg` hoặc `audio/flac`. Local không bắt buộc ngrok-skip-browser-warning, nhưng header này không gây lỗi. Không đặt thủ công Content-Type cho MultipartRequest.

Response upload:

~~~json
{
  "podcastId": "UUID_PODCAST",
  "podcastTitle": "Lịch sử Việt Nam - Tập 1",
  "status": "DRAFT",
  "media": {
    "objectKey": "podcasts/UUID_PODCAST/media.mp3",
    "bucket": "podcast-history",
    "publicUrl": null,
    "contentType": "audio/mpeg",
    "bytes": 12345678
  }
}
~~~

Frontend chỉ cần kiểm tra HTTP 2xx; response trả `contentType` là `video/*` hoặc `audio/*`. `objectKey` do backend quản lý, không tự ghi object key vào database.

## 10. Nguồn tham khảo và PDF (tùy chọn)

Tạo nguồn:

~~~http
POST /api/creator/podcasts/{podcastId}/references
Content-Type: application/json
~~~

| Field | Kiểu | Bắt buộc | Quy tắc |
|---|---|---:|---|
| referenceType | enum | Có | BOOK, ARTICLE, WEBSITE, PDF, OTHER |
| title | string | Có | Tối đa 300 ký tự |
| author | string | Không | Tối đa 200 ký tự |
| publisher | string | Không | Tối đa 200 ký tự |
| publishedYear | integer | Không | 1 đến 9999 |
| url | string | Không | Bắt đầu bằng http:// hoặc https:// |
| citationText | string | Không | Tối đa 10.000 ký tự |

~~~json
{
  "referenceType": "ARTICLE",
  "title": "Nguồn tham khảo lịch sử",
  "author": "Nguyễn Văn A",
  "publisher": "Nhà xuất bản",
  "publishedYear": 2024,
  "url": "https://example.com/article",
  "citationText": "Thông tin trích dẫn"
}
~~~

Lưu referenceId từ response nếu upload PDF:

~~~http
POST /api/creator/podcasts/{podcastId}/references/{referenceId}/file
Content-Type: multipart/form-data
~~~

Field vẫn là file, MIME type application/pdf, cách tạo MultipartRequest giống mục 9.

API reference còn lại:

~~~text
GET    /api/creator/podcasts/{podcastId}/references
GET    /api/creator/podcasts/{podcastId}/references/{referenceId}
PUT    /api/creator/podcasts/{podcastId}/references/{referenceId}
DELETE /api/creator/podcasts/{podcastId}/references/{referenceId}
GET    /api/creator/podcasts/{podcastId}/references/{referenceId}/file
DELETE /api/creator/podcasts/{podcastId}/references/{referenceId}/file
~~~

## 11. Kiểm tra trước khi submit

~~~http
GET /api/creator/podcasts/{podcastId}
Authorization: Bearer accessToken
~~~

Frontend nên kiểm tra podcastId, status, durationSeconds, mediaType, videoUrl, seriesId, visibility và exclusive. Sau upload, mediaType phải bắt đầu bằng `video/` hoặc `audio/` và podcast vẫn có thể ở trạng thái DRAFT.

## 12. Gửi podcast cho Admin duyệt

~~~http
POST /api/creator/podcasts/{podcastId}/submit
Authorization: Bearer accessToken
~~~

Không có body. Backend chỉ cho submit khi podcast thuộc Creator hiện tại, đã có media video hoặc audio và durationSeconds lớn hơn 0. Response submit trả `PENDING_REVIEW` trước khi AI hoàn tất. Nếu transcript hoàn tất và AI trả `SAFE` + `APPROVE`, backend tự chuyển podcast sang `APPROVED`; frontend cần tải lại chi tiết podcast để cập nhật trạng thái. Kết quả `REVIEW`, `REJECT` hoặc lỗi vẫn ở `PENDING_REVIEW` để Admin/Staff xử lý.

## 13. Đoạn code luồng hoàn chỉnh

~~~dart
final categories = await apiClient.get(
  '/api/categories',
  headers: {'ngrok-skip-browser-warning': '1'},
);

// categoryId lấy từ item user chọn.
final draft = await apiClient.post(
  '/api/creator/podcasts',
  body: {
    'categoryId': selectedCategoryId,
    'title': titleController.text.trim(),
    'description': descriptionController.text.trim(),
    'thumbnailUrl': thumbnailUrl,
    'durationSeconds': pickedDuration.inSeconds,
    'episodeNumber': episodeNumber,
    'visibility': isMembersOnly ? 'MEMBERS_ONLY' : 'PUBLIC',
  },
  headers: {'ngrok-skip-browser-warning': '1'},
);

final podcastId = draft['podcastId'] as String;

if (selectedSeriesId != null) {
  await apiClient.put(
    '/api/creator/podcasts/$podcastId/series',
    body: {'seriesId': selectedSeriesId},
    headers: {'ngrok-skip-browser-warning': '1'},
  );
}

await uploadPodcastMedia(
  baseUrl: baseUrl,
  accessToken: accessToken,
  podcastId: podcastId,
  bytes: videoBytes,
  filename: videoFilename,
  mimeType: videoMimeType,
);

final checked = await apiClient.get(
  '/api/creator/podcasts/$podcastId',
  headers: {'ngrok-skip-browser-warning': '1'},
);

final mediaType = checked['mediaType']?.toString() ?? '';
if (!mediaType.startsWith('video/') && !mediaType.startsWith('audio/')) {
  throw Exception('Backend chưa nhận media video/audio');
}

await apiClient.post(
  '/api/creator/podcasts/$podcastId/submit',
  headers: {'ngrok-skip-browser-warning': '1'},
);
~~~

Nếu upload lỗi thì dừng luồng, cho phép chọn lại file và không gọi submit.

## 14. API cho màn hình Creator Studio

Danh sách podcast:

~~~http
GET /api/creator/podcasts
~~~

Dashboard:

~~~http
GET /api/creator/dashboard?period=7d
~~~

period nhận 7d, 4w hoặc 12m.

Lịch sử review:

~~~http
GET /api/creator/podcasts/{podcastId}/reviews?page=0&size=20
~~~

Gửi appeal:

~~~http
POST /api/creator/podcasts/{podcastId}/appeals
Content-Type: application/json
~~~

~~~json
{
  "note": "Lý do đề nghị xem xét lại podcast"
}
~~~

## 15. Trạng thái và mã lỗi

| Trạng thái | Ý nghĩa |
|---|---|
| DRAFT | Đã tạo podcast nhưng chưa gửi duyệt |
| PENDING_REVIEW | Đã submit, đang chờ Admin |
| APPROVED hoặc PUBLISHED | Đã được duyệt/phát hành tùy response |
| REJECTED | Admin từ chối |
| ARCHIVED | Podcast đã lưu trữ |

| HTTP | Nguyên nhân | FE cần làm |
|---:|---|---|
| 400 | Thiếu field, UUID sai, duration không hợp lệ, visibility mâu thuẫn hoặc file không hợp lệ | Kiểm tra form/body |
| 401 | Thiếu hoặc hết hạn JWT | Refresh token hoặc đăng nhập lại |
| 403 | Không phải CREATOR, profile chưa APPROVED, hoặc không sở hữu podcast | Hiển thị lỗi quyền |
| 404 | Sai category, series, podcast hoặc reference ID | Tải lại dữ liệu và kiểm tra ID |
| 409 | Podcast đang ở trạng thái không cho sửa/submit | Cập nhật UI theo status |
| 413 | File vượt giới hạn server/proxy | Báo chọn file nhỏ hơn |
| 5xx | Backend, storage hoặc ngrok lỗi | Cho phép thử lại và giữ dữ liệu form |

## 16. Checklist frontend

- [ ] BASE_URL đúng môi trường và không có /api ở cuối.
- [ ] Đã lưu accessToken sau login.
- [ ] Dropdown category gửi categoryId, dropdown series gửi seriesId.
- [ ] Body create có categoryId, title, durationSeconds và visibility hoặc exclusive.
- [ ] Upload ảnh bìa/audio/video dùng multipart field chính xác là `file`.
- [ ] Nếu ảnh chọn từ máy, gọi `/api/creator/podcasts/{podcastId}/thumbnail` sau khi tạo draft.
- [ ] Kiểm tra response có `thumbnailUrl` trước khi gửi podcast duyệt.
- [ ] Request qua ngrok có ngrok-skip-browser-warning: 1.
- [ ] Không tự đặt Content-Type cho MultipartRequest.
- [ ] Chỉ gọi submit sau khi upload trả HTTP 2xx.
- [ ] Lưu và dùng đúng podcastId từ response create.

