# Kiểm thử API và tối ưu — 13/10/2026

## Kết quả

- Maven build thành công. Suite gọi HTTP thật tới Spring Boot, lấy danh mục API từ `/v3/api-docs`.
- Vòng cuối **664/664 kiểm tra đạt**, 0 thất bại; **163/163 operation** được gọi và đều có ít nhất một phản hồi 2xx. Operation = phương thức HTTP + đường dẫn. Vòng trước 663/663 đạt.
- Từng endpoint đã được gọi thành công không đồng nghĩa mọi nhánh và tổ hợp dữ liệu đều được kiểm tra.
- Mỗi lượt tạo database PostgreSQL riêng `podcast_history_api_test_<random>`, sau đó xóa. Dùng cổng ngẫu nhiên và S3 giả lập local. Không sửa `Podcast_History`, không dừng backend/ngrok của người dùng, không gọi Cloudflare/ngân hàng thật.
- Kết quả từng ca: `docs/api-tests/results-2026-10-13.json`.

## Phạm vi kiểm tra

| Nhóm | Kịch bản |
| --- | --- |
| Auth | Register/login, password sai, BCrypt trong DB, JWT 600 giây/refresh 604800 giây, JWT hết hạn/sai chữ ký, refresh rotation/replay, logout |
| User | Đổi thông tin/quyền, xác minh, khóa/mở khóa, thu hồi phiên, bảo vệ Admin, đăng ký đồng thời khác chữ hoa/thường |
| Creator | Xin/duyệt/từ chối hồ sơ kênh, podcast/series CRUD, gắn/gỡ series, upload video/ảnh/PDF, nguồn optional, chủ sở hữu |
| Listener | Search/playback public/thành viên/chủ kênh, progress, like, comment CRUD/SSE, follow, saved, history, report, subscription, yêu cầu nội dung |
| Moderation | Danh sách/preview/reviews, approve/reject/hide/restore/delete, khiếu nại, phân công/xử lý report |
| Thành viên | Checkout, ngăn trùng, đối soát thủ công, mở quyền nghe, hủy checkout/refund/đóng quyền, ngăn xử lý lặp |
| Ví | Giữ tiền một lần, thất bại hoàn tiền, hoàn tất không trừ lần hai, thiếu số dư, từ chối, duyệt đồng thời |
| Tranh chấp | Quyền mở đơn, tiếp tục/hủy/hoàn tất; hợp đồng và mốc là fixture DB test |
| HTTP | Anonymous 401, sai role 403, Staff bị chặn toàn bộ API Admin, UUID sai 400, ID thiếu 404, CORS |

## Sửa lỗi và tối ưu

1. File chứa HTML nhưng khai báo PNG từng nhận **201**. Sau sửa trả **400**. Thêm kiểm tra chữ ký định dạng ảnh/video; MP4 giả cũng bị chặn.
2. Register kiểm tra username trùng email tài khoản khác và ngược lại. Register/tạo Staff dùng khóa giao dịch PostgreSQL theo identifier, cùng thứ tự khóa. Test 4 đăng ký đồng thời khác chữ hoa/thường xác nhận chỉ tạo 1 tài khoản.
3. Like/follow/save/progress tuần tự hóa thao tác ghi theo user để tránh tranh chấp khi tạo lần đầu. Test 4 PUT đồng thời cho từng thao tác đều thành công; tài khoản khác ghi độc lập.
4. Thay video dọn object cũ sau commit và object mới khi rollback. Test thay video xác nhận object cũ bị xóa. Dọn file là best effort, lỗi R2 được ghi log; chưa có retry queue.
5. Video/PDF upload không trả public URL cố định. Playback object key luôn ký URL 5 phút, kể cả khi cấu hình public base URL. URL HTTP cũ của podcast public vẫn hỗ trợ; exclusive cần object key.
6. EntityGraph cho search/comment/history/saved/follow/subscription/request; payment và response trong danh sách lấy theo lô, tránh truy vấn từng hàng.
7. Search sắp xếp publishedAt + podcastId; comment thêm commentId. Test hai trang search không lặp ID.

## Đo truy vấn

Trước sửa, lượt lấy 20 podcast trong fixture phát sinh **23 SQL**. Sau sửa, search 20 podcast thuộc 20 category khác nhau phát sinh **3 SQL**: xác thực, danh sách, count. Suite kiểm tra kết quả search và tối đa 4 SQL để phát hiện N+1 trở lại.

Đây là đo truy vấn trên dữ liệu thử local, chưa benchmark throughput/độ trễ production. Các API List cũ vẫn giữ tương thích; chưa chuyển toàn bộ sang pagination.

## Chạy lại

Cần Java 17, Maven, Python 3, PostgreSQL 18; role DB có quyền tạo database. Thông tin DB đọc từ `Backend/.env` hoặc `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`. Python chỉ dùng standard library.

```powershell
cd D:\ki8\PRM_Team7\podcast_history\Backend
python scripts/api_regression.py
```

Lệnh build rồi chạy suite. Dùng `--skip-build` nếu vừa build xong. Đặt `PSQL_PATH` nếu psql không ở đường dẫn mặc định. Báo cáo nằm trong `Backend/target/api-regression/results.json`, log trong `server.log`. Exit code 0 = thành công, 1 = lỗi.

## Giới hạn

- R2 thật, bucket CORS, mạng/ngrok và chuyển khoản thật chưa test. S3 giả lập kiểm tra byte/lưu/đọc/xóa và URL ký, không xác thực chữ ký AWS.
- **Bucket chứa media private phải tắt public r2.dev/custom domain.** Backend ký URL không ngăn truy cập trực tiếp nếu bucket public. Public base URL cho ảnh cần cơ chế tách ảnh public khỏi media private. Chưa đổi cấu hình Cloudflare của người dùng.
- Chữ ký định dạng không thay thế quét virus hoặc giải mã/transcoding. Fixture video/PDF nhỏ chỉ kiểm tra API/storage, không kiểm tra phát video trong trình duyệt.
- Chưa load test, SSE nhiều instance, R2 lỗi trong rollback hay mọi nhánh trạng thái tài chính; không kết luận hệ thống không còn lỗi.
- Luồng CC nhận đơn/tạo hợp đồng/bàn giao/thanh toán từng mốc còn thiếu API. Test Admin dùng hợp đồng fixture. Creator Premium/livestream/AI moderation chưa triển khai; suite không đánh dấu các luồng này hoàn thành.
