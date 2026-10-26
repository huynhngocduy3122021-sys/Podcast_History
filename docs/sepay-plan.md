# Kế hoạch thay VNPay bằng SePay

## Phạm vi

- Thay tích hợp VNPay bằng SePay cho checkout membership hiện có; không thấy tích hợp PayOS trong source/frontend.
- Không sửa frontend: chưa tìm thấy tham chiếu VNPay/PayOS trong `Frontend/lib` hoặc `AdminWeb/src`.
- QR dùng URL ảnh nhúng chính thức `https://vietqr.app/img` với tham số `acc`, `bank`, `amount`, `des`. `qr.sepay.vn` là giao diện tạo/xem trước, tài liệu không mô tả endpoint ảnh `qr.sepay.vn/img`.

## File dự kiến xóa

- `Backend/src/main/java/com/prmteam7/podcasthistory/config/VnPayProperties.java`
- `Backend/src/main/java/com/prmteam7/podcasthistory/controller/VnPayController.java`
- `Backend/src/main/java/com/prmteam7/podcasthistory/dto/request/VnPayCreateRequest.java`
- `Backend/src/main/java/com/prmteam7/podcasthistory/dto/response/VnPayCreateResponse.java`
- `Backend/src/main/java/com/prmteam7/podcasthistory/service/VnPayService.java`
- `Backend/src/test/java/com/prmteam7/podcasthistory/service/VnPayServiceTest.java`

## File dự kiến sửa/thêm

- Sửa `Backend/src/main/java/com/prmteam7/podcasthistory/config/SecurityConfig.java`: bỏ quyền public cho route VNPay; chỉ mở public route webhook SePay. Giữ cấu hình CSRF hiện tại đang tắt toàn ứng dụng.
- Sửa `Backend/src/main/resources/application.properties`: thay cấu hình `vnpay.*` bằng `sepay.*` đọc các biến môi trường.
- Sửa `Backend/.env.example`: bỏ biến VNPay, thêm `SEPAY_WEBHOOK_API_KEY`, `SEPAY_ACCOUNT_NUMBER`, `SEPAY_BANK` và `SEPAY_PAYMENT_CODE_PREFIX`; chỉ để giá trị mẫu rỗng.
- Thêm `SepayProperties`, `SepayService`, `SepayController` cùng DTO request/response cho QR và trạng thái.
- Thêm test service cho xác thực/xử lý webhook, ít nhất một ca thanh toán hợp lệ và một ca bị từ chối hoặc lặp.

## API và xử lý

- `POST /api/payments/sepay/create`: yêu cầu đăng nhập; nhận `paymentId`, kiểm tra chủ sở hữu và trạng thái PENDING, gán provider `SEPAY`, tạo mã từ tiền tố cấu hình cộng phần ngẫu nhiên khó đoán, trả QR URL và dữ liệu thanh toán.
- `GET /api/payments/sepay/{paymentId}/status`: yêu cầu đăng nhập và kiểm tra chủ sở hữu; trả trạng thái Payment/Subscription để frontend poll.
- `POST /api/payments/sepay/webhook`: public; xác thực `Authorization: Apikey <API_KEY>` bằng so sánh constant-time; chỉ xử lý tiền vào có `code` khớp mã thanh toán và `transferAmount` khớp chính xác số tiền.
- Giao dịch hợp lệ chuyển Payment từ `PENDING` sang `PAID`, Subscription từ `PENDING` sang `ACTIVE`, cập nhật thời hạn theo gói. Khóa Payment khi xử lý để chống xử lý đồng thời; giao dịch lặp không kích hoạt/cộng trạng thái lần hai.
- Webhook hợp lệ, không khớp và đã xử lý đều được xác nhận `HTTP 200` với `{"success": true}`; API Key sai trả `401`. Không log API Key.

## Kiểm tra

- Chạy test service SePay và toàn bộ Maven test liên quan.
- Kiểm tra build backend.
- Demo: chạy backend tại `localhost:8081`, mở tunnel bằng `ngrok http 8081`, cấu hình URL webhook trên SePay thành `{ngrok-url}/api/payments/sepay/webhook`, rồi tạo checkout, quét QR và poll trạng thái.

## Trạng thái triển khai

Đã triển khai backend theo kế hoạch được duyệt:

- Thay controller/service/config VNPay bằng SePay; chỉ public webhook, các API tạo QR và xem trạng thái yêu cầu đăng nhập và kiểm tra chủ sở hữu.
- Checkout SePay chỉ nhận payment membership bằng VND đang PENDING; mã chuyển khoản có tiền tố cấu hình và phần ngẫu nhiên 96-bit.
- Webhook dùng `Authorization: Apikey ...`, so sánh constant-time, khóa Payment khi xử lý và chỉ kích hoạt membership nếu giao dịch tiền vào khớp chính xác mã và số tiền.
- QR được tạo từ `https://vietqr.app/img` với `acc`, `bank`, `amount`, `des`.
- Có test cho tạo QR, xác thực API Key, thanh toán hợp lệ/lặp và sai số tiền.

Frontend chưa được đổi: ứng dụng hiện tạo checkout nhưng chưa gọi API tạo QR hoặc hiển thị QR; đây là phần tiếp theo cần triển khai nếu muốn người dùng thanh toán trực tiếp từ ứng dụng. Cần cấu hình `SEPAY_WEBHOOK_API_KEY`, `SEPAY_ACCOUNT_NUMBER`, `SEPAY_BANK`, `SEPAY_PAYMENT_CODE_PREFIX` trong môi trường backend trước khi chạy checkout.
