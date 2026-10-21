# Danh mục `key`/`value` của quyền lợi gói CC

Tài liệu này ghi nhận các quyền lợi mà backend `podcast_history` hiện hiểu cho **gói CC đăng ký với hệ thống** (`/api/admin/creator-system-plans`). Đây là gói chung cho mọi CC, khác với membership plan của listener theo từng kênh (`/api/admin/membership-plans`).

Admin gửi quyền lợi trong mảng `benefits` khi gọi `POST /api/admin/creator-system-plans` hoặc `PUT /api/admin/creator-system-plans/{planId}`. Mỗi phần tử có dạng:

```json
{ "key": "UPLOAD_LIMIT", "value": "3", "description": "Tối đa 3 podcast có video/audio" }
```

## Những key backend hiện nhận biết

| Key | Value hợp lệ | Backend đang làm gì | Tình trạng |
| --- | --- | --- | --- |
| `UPLOAD_LIMIT` | Chuỗi số nguyên không âm, ví dụ `"0"`, `"3"`, `"100"`; hoặc `"unlimited"` | Giới hạn số podcast của kênh đã có media video/audio. API upload media lần đầu cho podcast kiểm tra quota trước khi lưu. | **Đang thực thi** |
| `LIVESTREAM` | `"true"` hoặc `"false"` | Trả `canLivestream` trong `GET /api/creator/system-plans/me`. | **Chỉ là cờ quyền**; chưa có API phát livestream |

Quy tắc `UPLOAD_LIMIT`:

- Nếu thiếu key, giới hạn mặc định là **0**; nếu `value` là `"unlimited"`, trường `uploadLimit` và `uploadsRemaining` trong phản hồi là `null`.
- Mỗi podcast có `media_url` được tính một lượt trong tổng lượt đã đăng của kênh. Thay file video/audio của cùng podcast không tính thêm lượt. Đổi gói hoặc hết hạn Plus **không đặt lại** tổng lượt đã đăng.
- Khi vượt giới hạn, `POST /api/creator/podcasts/{podcastId}/video` trả `403` trước khi upload lên R2. Để kiểm tra bằng file thực, kho R2 phải được cấu hình và CC phải có hồ sơ đã duyệt.

## Key do admin tự thêm

Admin có thể thêm key mới, ví dụ:

```json
{ "key": "PRIORITY_SUPPORT", "value": "true", "description": "Ưu tiên hỗ trợ" }
```

Backend **lưu và trả lại** key này trong danh sách gói và subscription. Nó **chưa tự tạo ra hành vi** vì chưa có chức năng đọc `PRIORITY_SUPPORT`. Tương tự, nhập `CHANNEL_VIEW_LIMIT` sẽ **chưa giới hạn lượt xem kênh**.

Để một key mới có hiệu lực, cần xác định rõ cách đếm và thời hạn, thêm logic đọc key ở chức năng tương ứng, lưu số lượt đã dùng nếu cần, và trả lỗi khi vượt quyền. Ví dụ `CHANNEL_VIEW_LIMIT` cần xác định đếm mỗi lượt mở kênh hay mỗi người xem duy nhất, rồi tích hợp kiểm tra vào API xem kênh. Chỉ thêm key/value trong Swagger là chưa đủ.

## Quy tắc nhập liệu

- `key`: bắt đầu bằng chữ cái, theo sau là chữ cái, số hoặc `_`, tối đa 60 ký tự. Backend chuẩn hóa thành chữ hoa. Không được trùng key trong cùng một gói.
- `value`: chuỗi không rỗng, tối đa 200 ký tự. `description` tùy chọn, tối đa 500 ký tự. Mỗi gói tối đa 30 quyền lợi.
- Với hai key được thực thi, backend kiểm tra định dạng `value` như bảng trên. Các key khác hiện chỉ được lưu và hiển thị.
- Admin cập nhật **toàn bộ mảng** `benefits` bằng `PUT`; quyền lợi nào bị bỏ khỏi mảng sẽ không còn trong gói cho lượt mua mới.

## Khi nào thay đổi có hiệu lực?

- Free là gói mặc định. Sửa quyền lợi Free áp dụng ngay cho CC không có gói trả phí đang hiệu lực.
- Khi CC đăng ký gói trả phí qua `POST /api/creator/system-plans/{planId}/subscribe`, backend lưu bản quyền lợi của gói tại thời điểm mua. Sửa gói sau đó chỉ ảnh hưởng lượt mua mới; CC đã mua giữ quyền lợi đến khi hết hạn.
- `GET /api/creator/system-plans/me` hiển thị quyền lợi đang áp dụng, `uploadLimit`, `uploadsUsed`, `uploadsRemaining` và `canLivestream`.

## Nơi triển khai trong mã nguồn

- `Backend/src/main/java/com/prmteam7/podcasthistory/config/DatabaseSeeder.java`: dữ liệu Free và Plus ban đầu. Đây chỉ là giá trị khởi tạo; admin có thể sửa qua API.
- `Backend/src/main/java/com/prmteam7/podcasthistory/service/CreatorSystemPlanService.java`: kiểm tra value, tính quyền lợi hiện hành và quota upload.
- `Backend/src/main/java/com/prmteam7/podcasthistory/service/CreatorFlowService.java`: gọi kiểm tra quota trước khi upload video/audio đầu tiên cho podcast.
- `Backend/src/main/java/com/prmteam7/podcasthistory/dto/request/CreatorSystemPlanWrite.java`: quy tắc định dạng request.

Danh mục này phản ánh **code hiện tại**, không phải danh sách mọi quyền lợi có thể tạo trong tương lai. Khi thêm logic cho một key mới, cập nhật bảng “Những key backend hiện nhận biết” cùng thay đổi code.
