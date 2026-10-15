# Bình luận gắn mốc video

## Tạo bình luận

`POST /api/podcasts/{podcastId}/comments` với Bearer access token:

```json
{
  "content": "Đoạn này giải thích rất hay",
  "timestampSeconds": 1080
}
```

`1080` giây = **18:00** trên video. Frontend đọc vị trí player ngay lúc người dùng bấm gửi (Flutter: `controller.value.position.inSeconds`). Backend không biết player đang ở đâu và không dùng thời gian đồng hồ hoặc lịch sử nghe làm mốc thay thế.

Có thể bỏ `timestampSeconds` hoặc gửi null cho bình luận không gắn thời gian. Số âm hoặc lớn hơn `Podcast.durationSeconds` trả 400; 0 là mốc bắt đầu. Đây là vị trí do client cung cấp, không phải bằng chứng người dùng đã xem tới thời điểm đó.

## Đọc và hiển thị

Response tạo/sửa bình luận, `GET /api/podcasts/{podcastId}/comments` (từng phần tử `content`) và SSE `GET /api/podcasts/{podcastId}/comments/stream` đều có `timestampSeconds`:

```json
{
  "content": "Đoạn này giải thích rất hay",
  "timestampSeconds": 1080
}
```

Đây là phần trích response; các field ID, tác giả, trạng thái, createdAt/updatedAt vẫn giữ nguyên.

Frontend hiển thị `18:00` dưới bình luận; khi bấm, gọi `controller.seekTo(Duration(seconds: comment.timestampSeconds))`. Định dạng `H:MM:SS` nếu video dài hơn một giờ; null thì ẩn nhãn. `createdAt` vẫn là thời điểm gửi theo đồng hồ, khác với vị trí trên video.

`PUT /api/comments/{commentId}` vẫn chỉ sửa `content` và giữ nguyên mốc video ban đầu. Xóa comment vẫn dùng API hiện tại. SSE tạo bình luận mới tự chứa mốc; phần hiển thị nhãn và seek của frontend cần nối vào API này.

## Database

Lưu trong `public."Comment".timestamp_seconds` (integer nullable). Bình luận cũ giữ null; không gán giả về 0.

Migration PostgreSQL: `Backend/db/migrations/2026-10-15_comment_video_timestamp.sql`. Với cấu hình hiện tại `spring.jpa.hibernate.ddl-auto=update`, cột được thêm khi restart backend. Nếu môi trường dùng validate/none, chạy migration trước khi khởi động bản mới. Không xóa hay đổi nội dung bình luận cũ.

## Sửa lỗi giao diện Listener — 15/10/2026

Đã kiểm tra backend local đang chạy và ngrok: request comment đều có `timestampSeconds`; bảng `Comment` đã có cột tương ứng. Tại thời điểm kiểm tra có 8 bản ghi. Các lỗi tìm được trong player Listener:

- Callback gửi comment có thể null trên podcast mẫu, nhưng code cũ coi đó là gửi thành công và chỉ thêm comment vào bộ nhớ.
- API client chỉ gửi content, thiếu timestampSeconds. Danh sách đọc từ API lại hiển thị mọi mốc thành 00:00.
- Player xóa nội dung nhập trước khi biết API có lưu được hay không; thời gian player dùng độ dài cố định 32 phút.
- Lỗi ở các request phụ có thể làm việc nạp danh sách podcast thật không hoàn tất, để giao diện tiếp tục hiển thị mẫu.
- Listener API chưa tự refresh access token khi hết hạn.

Đã sửa: chỉ thêm comment do API trả về có commentId, chờ API xong mới xóa ô nhập, giữ bản nháp và hiển thị lỗi khi gửi thất bại, chặn podcast mẫu không có API callback. Gửi mốc theo progress và độ dài của podcast hiện tại, đọc lại từ DB mỗi lần mở player. Các request phụ không chặn nạp catalog. Request HTTP gặp 401 sẽ refresh một lần rồi thử lại; các request đồng thời dùng chung một lần refresh. Refresh token mới được cập nhật vào session để logout sử dụng đúng token.

Sau khi sửa cần **Hot Restart hoặc chạy lại Flutter**, đăng nhập và chọn podcast thật đã được duyệt. Hot Reload có thể giữ API client và dữ liệu mẫu trong State cũ. Ngrok đang truy cập được tại lúc kiểm tra; chưa thay đổi hoặc khởi động lại tunnel.

Chạy frontend local nếu cần bỏ qua tunnel:

```powershell
cd Frontend
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8081
```

Android emulator dùng host `http://10.0.2.2:8081`; thiết bị thật cần địa chỉ backend truy cập được hoặc ngrok. Không để localhost của điện thoại trỏ nhầm về chính điện thoại.

### Kiểm tra lại

```powershell
# Trong Frontend
flutter test test/listener_comment_persistence_test.dart

# Trong Backend: PostgreSQL 18 đang chạy, role có quyền tạo DB
python scripts/comment_regression.py
```

- 6/6 test Flutter đạt: gửi đúng ID/token/mốc, đọc mốc, refresh đồng thời, lỗi API không tạo dữ liệu giả, chờ xác nhận lưu và giữ draft khi lỗi.
- 56/56 bước HTTP/DB đạt (bao gồm chuẩn bị tài khoản, kênh và podcast): xác nhận POST ghi nội dung + 1080 giây vào PostgreSQL bằng truy vấn SQL trên kết nối riêng; GET trả lại cùng ID/mốc; sửa nội dung giữ mốc; kiểm tra giá trị âm/vượt độ dài/rỗng/chưa đăng nhập và xóa mềm.
- DB của regression là DB riêng tự tạo/xóa, storage giả lập. Không thêm comment test vào Podcast_History, không gọi Cloudflare thật. Chưa thao tác toàn bộ ứng dụng bằng trình duyệt với tài khoản thật.
- Thay đổi lần này áp dụng cho player Listener. Các widget Creator Studio đang dùng mock có luồng riêng.
