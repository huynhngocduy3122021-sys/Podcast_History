# Sửa lỗi backend sau cập nhật dev — 15/10/2026

## Nguyên nhân

Bản merge `63798cb` có khai báo trùng trong ProducerProfileRepository và GlobalExceptionHandler; thiếu import EntityGraph; mất method repository đang được service Admin/Listener sử dụng; enum tranh chấp hợp đồng bị thay bởi enum tranh chấp từng mốc; code upload PDF bị cắt mất phần kiểm tra/lưu file và hàm xóa. Các lỗi này khiến javac thất bại.

Khi khởi động còn gặp `Ambiguous mapping`: hai controller cùng đăng ký POST `/api/admin/disputes/{disputeId}/resolve`. Ngoài ra cấu hình merge bỏ CORS và rule Staff, chuyển route mặc định thành permitAll.

## Điều chỉnh

- Hợp nhất repository, giữ các truy vấn mới và khôi phục truy vấn/khóa/phân trang/truy vấn theo lô cũ.
- Bỏ handler trùng, giữ xử lý lỗi workflow mới.
- Giữ DisputeDecision cho hợp đồng; thêm MilestoneDisputeDecision cho mốc.
- API tranh chấp mốc chuyển sang GET `/api/admin/milestone-disputes/open` và POST `/api/admin/milestone-disputes/{disputeId}/resolve`. API tranh chấp hợp đồng vẫn ở `/api/admin/disputes`.
- Khôi phục upload/xóa PDF; thêm upload audio/video riêng cho milestone thay vì gọi API upload ảnh. Object key có đường dẫn theo milestone và không trả URL public cố định.
- Khôi phục CORS, bảo vệ `/api/staff/**`, yêu cầu xác thực cho các route còn lại; GET categories vẫn public.
- Thêm default 0 cho amount của ContractStage khi Hibernate tạo cột trên DB cũ.
- Giữ phần comment gắn timestampSeconds. Không sửa Frontend/pubspec.lock đang có thay đổi local.

## Xác nhận

`mvn -f Backend/pom.xml '-Dmaven.test.skip=true' clean package`: BUILD SUCCESS, biên dịch sạch 192 source files.

Khởi động JAR thành công trên cổng ngẫu nhiên với PostgreSQL tạm riêng, xác nhận JPA repository và mapping controller khởi tạo được. Đã dừng tiến trình chẩn đoán và xóa DB tạm; không đổi dữ liệu Podcast_History. Log lần khởi động trong `Backend/target/merge-startup.log`.

Chưa chạy lại bộ kiểm thử API/nghiệp vụ hoặc Cloudflare thật trong lượt sửa này. Với DB hiện hữu, migration workflow milestone nằm ở `Backend/db/migrations/2026-10-13_podcast_request_milestones.sql`; xem README trước khi triển khai.

Khởi động lại từ Backend: `mvn clean spring-boot:run`. Nếu đang có tiến trình chiếm 8081, dừng tiến trình backend cũ trước.
