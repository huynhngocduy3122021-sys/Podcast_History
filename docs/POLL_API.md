# Poll một câu hỏi, nhiều option

## Database và phạm vi

- `public."Polll"`: câu hỏi, chủ kênh, trạng thái, thời gian mở/đóng, series và podcast tùy chọn.
- `public."Polll_questions"`: **các option trả lời**, không phải nhiều câu hỏi của một biểu mẫu. Mỗi option có `poll_option_id`, `poll_id`, `option_text`, `sort_order`.
- `public."Poll_votes"`: lựa chọn của Listener, liên kết user/poll/option. Unique `(user_id, poll_id)` giữ một câu trả lời cho mỗi người trên mỗi poll.
- Giữ tên bảng ERD đang dùng, không xóa hoặc đổi tên các bảng trên. Migration `Backend/db/migrations/2026-10-16_poll_api.sql` đã áp dụng trên DB local: series nullable, thêm row_version và index. Bản ghi hiện hữu được giữ lại.
- Poll thuộc kênh CC; `seriesId` và `podcastId` đều nullable. Cả hai null (hoặc bỏ hai trường) là poll chung của kênh. Có thể chỉ gắn series, chỉ gắn podcast, hoặc gắn cả hai nếu đều thuộc kênh của mình; hai liên kết độc lập, không ép podcast phải thuộc series được chọn.
- ID được gửi phải thuộc kênh CC hiện tại và nội dung chưa lưu trữ/xóa. PUT khi còn DRAFT có thể gửi null để gỡ liên kết; trường bị bỏ trong PUT cũng được hiểu là null.
- Migration bổ sung `Backend/db/migrations/2026-10-16_poll_podcast_link.sql` đã áp dụng local: thêm podcast_id nullable và khóa ngoại tới Podcast; series_id vẫn nullable.
- Hiện các Creator đã được duyệt có thể dùng. Chưa gắn điều kiện Creator Premium vì billing/entitlement Premium chưa có trong backend; đây không phải gói membership kênh.

## Trạng thái và quy tắc

`DRAFT → OPEN → CLOSED`; có thể xóa mềm thành `DELETED`.

- Tạo mới luôn là DRAFT, Listener không thấy bản nháp.
- Chỉ DRAFT được sửa câu hỏi, option và thời gian. PUT thay toàn bộ option; option ID có thể đổi. Sau công bố không sửa nội dung, kể cả khi chưa có người trả lời.
- Có 2–20 option, mỗi option 1–300 ký tự; không trùng nhau sau trim và không phân biệt hoa/thường. Câu hỏi tối đa 5000 ký tự.
- `startsAt` không gửi thì lấy thời điểm hiện tại; `endsAt` có thể null. Nếu có, endsAt phải sau startsAt.
- Publish cho Listener xem poll. Chỉ nhận câu trả lời khi OPEN, đã tới startsAt và chưa tới endsAt. Hết hạn tự ngừng nhận nhưng trạng thái lưu vẫn OPEN tới khi CC gọi close; frontend đọc `acceptingResponses` để bật/tắt gửi.
- CLOSED vẫn xem được câu hỏi/kết quả, không gửi/đổi/rút câu trả lời. Không có API mở lại poll đã đóng.
- DELETE poll là xóa mềm, ẩn khỏi các API đọc, giữ option và câu trả lời trong DB.
- Creator chỉ quản lý poll của kênh mình. Poll kênh chưa duyệt/đã khóa không hiển thị cho Listener.
- Chỉ role LISTENER được gửi/đổi/rút câu trả lời; userId luôn lấy từ JWT. Không yêu cầu membership kênh cho poll hiện tại.
- Gửi mới lần hai trả 409; dùng PUT để đổi option. Option từ poll khác bị từ chối 400. Rút rồi có thể gửi lại trong thời hạn.
- Danh sách người trả lời chỉ chủ kênh xem được. Listener chỉ xem lựa chọn của mình và thống kê tổng hợp.
- Thao tác ghi dùng khóa transaction trên poll để tuần tự hóa với close/delete, cộng với unique user–poll ở DB. Đổi lựa chọn giữ responseId và thời điểm gửi ban đầu; rút lựa chọn xóa bản ghi vote khỏi DB.

## API của Creator — Bearer token role CREATOR

| Method | Path | Chức năng |
| --- | --- | --- |
| GET | `/api/creator/polls?status=DRAFT&page=0&size=20` | Danh sách của mình; status tùy chọn |
| POST | `/api/creator/polls` | Tạo mới, trả 201 |
| GET | `/api/creator/polls/{pollId}` | Chi tiết và option |
| PUT | `/api/creator/polls/{pollId}` | Sửa khi còn DRAFT |
| DELETE | `/api/creator/polls/{pollId}` | Xóa mềm, trả 204 |
| POST | `/api/creator/polls/{pollId}/publish` | Công bố |
| POST | `/api/creator/polls/{pollId}/close` | Đóng |
| GET | `/api/creator/polls/{pollId}/results` | Tổng số lượt, số lượt/tỷ lệ theo option |
| GET | `/api/creator/polls/{pollId}/responses?page=0&size=20` | Danh sách người trả lời |

Body POST và PUT:

```json
{
  "question": "Bạn muốn nghe chủ đề lịch sử nào tiếp theo?",
  "options": ["Thời Lý", "Thời Trần", "Thời Nguyễn"],
  "seriesId": null,
  "podcastId": null,
  "endsAt": null
}
```

Chi tiết trả theo cấu trúc `{"poll": {...}, "options": [...]}`. `poll.pollId` là ID dùng cho publish/close và các API đọc. Mỗi phần tử options có `optionId`, `text`, `sortOrder`; frontend dùng đúng optionId do backend trả về khi gửi câu trả lời.

`poll.seriesId` và `poll.podcastId` trả lại liên kết tương ứng, có thể null. Chỉ thay `podcastId` bằng UUID thật để gắn vào podcast; không cần chọn series.

Creator và Listener có thể thêm query `seriesId` hoặc `podcastId` vào API danh sách để lọc poll theo nội dung:

```http
GET /api/creator/polls?podcastId=<UUID-podcast>
GET /api/creators/{creatorId}/polls?seriesId=<UUID-series>
GET /api/creators/{creatorId}/polls?podcastId=<UUID-podcast>
```

Nếu gửi cả hai bộ lọc, kết quả phải khớp cả hai. Nếu không lọc thì bỏ query parameter; không gửi chuỗi `null` trong URL. Việc gắn nội dung chỉ là liên kết poll, không tự thay đổi quyền phát video hoặc quyền nhận trả lời của poll.

## API Listener / xem poll đã công bố — Bearer token

| Method | Path | Chức năng |
| --- | --- | --- |
| GET | `/api/creators/{creatorId}/polls?page=0&size=20` | Poll đã công bố của kênh; creatorId là ID Creator_profile |
| GET | `/api/polls/{pollId}` | Chi tiết và option |
| GET | `/api/polls/{pollId}/results` | Kết quả tổng hợp, không có danh tính người khác |
| POST | `/api/polls/{pollId}/responses` | Gửi lựa chọn lần đầu, trả 201 |
| GET | `/api/polls/{pollId}/responses/me` | Xem câu trả lời của tôi; chưa gửi trả 404 |
| PUT | `/api/polls/{pollId}/responses/me` | Đổi lựa chọn, trả 200 |
| DELETE | `/api/polls/{pollId}/responses/me` | Rút lựa chọn, trả 204 |

Body gửi/đổi câu trả lời:

```json
{
  "optionId": "UUID-option-lấy-từ-API-chi-tiết"
}
```

Kết quả tổng hợp có `totalResponses` và danh sách options: `responseCount`, `percentage` (làm tròn 2 chữ số thập phân; không có lượt chọn thì 0). Không trả danh sách user cho API kết quả Listener.

### Thứ tự gọi

1. CC đăng nhập → POST tạo poll → lấy poll.pollId/options → sửa bằng PUT nếu cần.
2. CC POST publish.
3. Listener đăng nhập → GET poll của kênh → GET chi tiết → POST responses với optionId.
4. Listener GET responses/me; PUT để đổi hoặc DELETE để rút khi poll còn nhận trả lời.
5. CC GET results và GET responses; POST close khi muốn kết thúc.

Các danh sách dùng page từ 0, size mặc định 20 và tối đa 100. Lỗi dữ liệu 400, thiếu JWT 401, sai role 403, không tồn tại/không thuộc quyền sở hữu 404, sai trạng thái/đã trả lời 409.

## Triển khai

Đã build Maven và kiểm tra HTTP trên PostgreSQL tạm riêng bằng `Backend/scripts/poll_regression.py`: **95/95 kiểm tra thành công**, gồm thiết lập tài khoản và cả **16 endpoint poll**. Kiểm tra CRUD, công bố/đóng, trả lời/đổi/rút lựa chọn, tổng hợp kết quả, phân quyền, liên kết series/podcast nullable, lọc danh sách, thời hạn và gửi đồng thời. Báo cáo: `Backend/target/poll-regression/results.json`.

Đã sửa lỗi 500 khi POST tạo poll (`TransientPropertyValueException`): `PollService.create` phải dùng đối tượng trả về từ `polls.save(poll)` để gắn các option. Với entity có version, JPA có thể trả một đối tượng managed khác; dùng đối tượng cũ làm liên kết khiến lưu option thất bại và transaction rollback. Database local đã được đối chiếu, hai liên kết `series_id`/`podcast_id` cho phép NULL và các khóa ngoại hiện có đầy đủ.

Chạy lại kiểm thử từ thư mục `Backend`: `python scripts/poll_regression.py` (cần Java, Maven, Python và PostgreSQL local; script tự tạo/xóa DB kiểm thử riêng).

Restart backend để Swagger xuất hiện nhóm **Content Creator - polls** và **Listener - polls**. Máy khác cần chạy migration trước nếu DB có sẵn bảng; DB trống có thể để Hibernate tạo schema theo cấu hình dự án. Chưa nối các API mới vào giao diện Flutter.
