# Quyền xem podcast

Khi tạo hoặc cập nhật podcast, chọn `visibility`:

- `PUBLIC`: mọi người dùng đã đăng nhập có thể xem sau khi Admin duyệt.
- `MEMBERS_ONLY`: sau khi duyệt, chỉ chủ kênh hoặc thành viên kênh còn hiệu lực được xem.

```json
{
  "categoryId": "UUID-category",
  "title": "Bối cảnh Việt Nam",
  "description": "Nội dung podcast",
  "durationSeconds": 1800,
  "episodeNumber": 1,
  "visibility": "MEMBERS_ONLY"
}
```

Các API tạo/cập nhật: `POST /api/creator/podcasts`,
`PUT /api/creator/podcasts/{podcastId}`.
Trường cũ `exclusive` vẫn được chấp nhận: `false` = `PUBLIC`,
`true` = `MEMBERS_ONLY`. Phải gửi ít nhất một trong hai; nếu gửi cả hai
thì phải khớp, nếu không API trả `400`. Response Creator, Listener và Admin
trả cả `visibility` và `exclusive`. DB tiếp tục lưu trong `Podcast.is_exclusive`.

## Xem media qua API Listener

`GET /api/podcasts/{podcastId}/playback` yêu cầu JWT của tài khoản đang hoạt động.
Frontend dùng `playbackUrl`; gọi lại API khi URL có chữ ký hết hạn.

Creator có thể lấy link trực tiếp trong `GET /api/creator/podcasts/{podcastId}`:
response có `videoUrl` và `videoUrlExpiresAt` dùng cho media video hoặc audio. URL có chữ ký hiệu lực 5 phút;
URL public có `videoUrlExpiresAt=null`. Chưa upload media hoặc podcast đã xóa
thì `videoUrl=null`. Quyền sở hữu vẫn được kiểm tra trước khi cấp URL.

| Trạng thái | Chủ kênh đang hoạt động, hồ sơ đã duyệt | Người nghe khác |
|---|---|---|
| DRAFT/PENDING_REVIEW/REJECTED | Xem trước nếu đã có media video/audio | Không được xem |
| APPROVED/PUBLISHED, PUBLIC | Được xem | Được xem |
| APPROVED/PUBLISHED, MEMBERS_ONLY | Được xem, không cần mua thành viên | Cần thành viên kênh còn hiệu lực |
| DELETED | Không được xem | Không được xem |

Quyền xem trước của chủ kênh áp dụng cả API chi tiết, tiến độ nghe và tài liệu nguồn.
Danh sách khám phá vẫn chỉ trả podcast đã duyệt/xuất bản, không đưa bản nháp ra công khai.
Tài khoản có role Creator khác không được xem trước podcast của kênh khác.
