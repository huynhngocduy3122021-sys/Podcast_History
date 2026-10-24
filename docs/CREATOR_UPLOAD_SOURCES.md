# Đăng podcast kèm tài liệu nguồn

Các API dùng `Authorization: Bearer <accessToken>`.
Creator phải có role `CREATOR`, tài khoản hoạt động và hồ sơ đã được duyệt.

1. Lấy `categoryId` từ `GET /api/categories`.
2. Tạo nháp qua `POST /api/creator/podcasts`, lưu `podcastId`.
3. Upload video hoặc audio qua `POST /api/creator/podcasts/{podcastId}/video`, multipart field `file`.
4. Tạo nguồn qua `POST /api/creator/podcasts/{podcastId}/references`, lưu `referenceId`.
5. Upload PDF qua `POST /api/creator/podcasts/{podcastId}/references/{referenceId}/file`, multipart field `file`.
6. Gửi duyệt qua `POST /api/creator/podcasts/{podcastId}/submit`.
7. Admin đọc nguồn/tải PDF và duyệt podcast bằng API quản trị.

Body thêm/cập nhật nguồn:

```json
{
  "referenceType": "PDF",
  "title": "Tài liệu bối cảnh lịch sử Việt Nam",
  "author": "Tên tác giả",
  "publisher": "Tên nhà xuất bản",
  "publishedYear": 2024,
  "url": "https://example.com/tai-lieu-goc",
  "citationText": "Tham khảo chương 2, trang 15–30."
}
```

`referenceType` nhận `BOOK`, `ARTICLE`, `WEBSITE`, `PDF`, `OTHER`.
Chỉ `referenceType` và `title` là bắt buộc. Nếu không có URL, bỏ trường `url`
hoặc gửi `null`. File PDF được gắn qua API upload; request metadata không nhận
object key hay URL file tùy ý.

## CRUD Creator

Base path: `/api/creator/podcasts/{podcastId}/references`

| Method | Path | Chức năng |
|---|---|---|
| POST | base path | Tạo nguồn; `201` và `referenceId` |
| GET | base path | Danh sách nguồn |
| GET | `/{referenceId}` | Metadata nguồn |
| PUT | `/{referenceId}` | Thay metadata, giữ PDF |
| DELETE | `/{referenceId}` | Xóa nguồn và dọn PDF; `204` |
| POST | `/{referenceId}/file` | Upload/thay PDF; `200` |
| GET | `/{referenceId}/file` | `downloadUrl` có chữ ký và `expiresAt` |
| DELETE | `/{referenceId}/file` | Gỡ PDF, giữ metadata; `204` |

PDF phải có đuôi `.pdf`, MIME `application/pdf` hoặc `application/octet-stream`,
và phần đầu file `%PDF-`. Giới hạn theo `MEDIA_UPLOAD_MAX_FILE_SIZE` (100MB mặc định).
R2 cần endpoint, access key, secret key và bucket. URL public không bắt buộc;
API cấp URL tải có chữ ký hiệu lực 5 phút.

Object key lưu trong `Podcast_reference.file_url`, response tên `fileKey`.
File nằm trong thư mục riêng của user/podcast/reference. Sau khi giao dịch DB
thành công, server dọn file cũ nếu thay/xóa; rollback thì dọn file mới upload.
Lỗi dọn R2 được ghi log để xử lý lại.

Sửa nguồn chỉ cho phép trên `DRAFT`/`REJECTED`. Sửa nguồn của podcast
`APPROVED`/`PUBLISHED` đưa podcast về `DRAFT` để duyệt lại. `PENDING_REVIEW`
và `DELETED` không cho phép sửa. Reference phải thuộc podcast trong URL;
podcast phải thuộc Creator đang đăng nhập.
Nguồn là tùy chọn; điều kiện gửi duyệt yêu cầu podcast đã có media video hoặc audio.

## Admin và Listener

Admin có thể xem cả bản nháp/chờ duyệt:

- `GET /api/admin/podcasts`: tất cả podcast, gồm đã chấp nhận và từ chối; mỗi item có `status`.
- `GET /api/admin/podcasts?status=APPROVED`: lọc đã chấp nhận.
- `GET /api/admin/podcasts?status=REJECTED`: lọc bị từ chối.
- `GET /api/admin/podcasts?status=PENDING_REVIEW`: lọc chờ duyệt.

- `GET /api/admin/podcasts/{podcastId}/references`
- `GET /api/admin/podcasts/{podcastId}/references/{referenceId}/file`

Listener xem nguồn của podcast đã duyệt:

- `GET /api/podcasts/{podcastId}/references`
- `GET /api/podcasts/{podcastId}/references/{referenceId}/file`

Listener phải đăng nhập. Nội dung độc quyền yêu cầu thành viên kênh còn hiệu lực;
chủ kênh được miễn điều kiện thành viên và có thể xem trước nguồn của podcast mình
chưa duyệt, dùng cùng quy tắc quyền với API phát podcast.
Xem [quyền xem podcast](PODCAST_VISIBILITY.md).
