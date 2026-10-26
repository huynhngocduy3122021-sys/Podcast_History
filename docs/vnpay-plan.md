# Kế hoạch tích hợp VNPay (API 2.1.0)

## Mục tiêu
- Tích hợp cổng thanh toán VNPay cho flow membership subscription hiện có dựa trên `Subscription` + `Payment`.
- Chỉ triển khai tạo URL thanh toán và IPN callback theo chuẩn VNPay 2.1.0.
- Không dùng Return URL để xác nhận thanh toán; IPN mới là nguồn tin cậy.
- Dựng cấu trúc tách riêng để mở rộng querydr/refund sau này mà không phá vỡ flow hiện tại.

## Dữ liệu và flow hiện tại
- `ListenerFlowService.createMembershipCheckout()` tạo `Subscription(status=PENDING)` và `Payment(status=PENDING)`.
- `AdminFinanceService.reconcile()` hiện dùng thủ công để chuyển `PENDING -> PAID` và kích hoạt membership; flow này sẽ được giữ nguyên ở frontend/admin.
- Ý tưởng VNPay: tạo một URL thanh toán dựa trên `Payment` đang ở `PENDING`, lưu `TxnRef` vào `Payment.providerTransactionId`, và khi IPN nhận được xác nhận thành công thì cập nhật `Payment.status = PAID` và `Subscription.status = ACTIVE` tương tự logic hiện có.

## File dự kiến sửa/tạo
- `Backend/src/main/java/com/prmteam7/podcasthistory/config/VnPayProperties.java`
  - Bind config `vnpay.*` từ env / `.env` / application properties.
- `Backend/src/main/java/com/prmteam7/podcasthistory/service/VnPayService.java`
  - Sinh `vnp_TxnRef`, tạo/verify `secure hash`, build payment URL.
- `Backend/src/main/java/com/prmteam7/podcasthistory/controller/VnPayController.java`
  - `POST /api/payments/vnpay/create` (Yêu cầu login)
  - `GET /api/payments/vnpay/return` (public, chỉ hiển thị kết quả)
  - `POST /api/payments/vnpay/ipn` (public, verify chữ ký, idempotent)
- `Backend/src/main/java/com/prmteam7/podcasthistory/dto/request/VnPayRequest.java`
  - DTO request cho tạo URL thanh toán.
- `Backend/src/main/java/com/prmteam7/podcasthistory/dto/response/VnPayResponse.java`
  - DTO response cho URL thanh toán và kết quả callback.
- `Backend/src/main/resources/application.properties`
  - Thêm các default key `vnpay.*` rỗng/blank, không hardcode secret.
- `Backend/.env.example`
  - Mô tả biến môi trường cần set cho sandbox/production.
- `Backend/src/main/java/com/prmteam7/podcasthistory/config/SecurityConfig.java`
  - Cho phép public route cho `/api/payments/vnpay/**` (IPN/Return), vẫn giữ auth cho endpoint tạo URL.

## Luồng xử lý
1. User gọi `POST /api/payments/vnpay/create` với `paymentId` và tùy chọn `orderInfo`.
2. Backend tìm `Payment` đang `PENDING`, kiểm tra quyền sở hữu, xác định `amount`, `currency` và `subscription` liên quan.
3. Tạo `vnp_TxnRef` theo format `SUB-YYYYMMDDHHMMSS-RANDOM`, lưu vào `Payment.providerTransactionId` và `Payment.provider = "VNPAY"`.
4. Tạo URL thanh toán theo chuẩn VNPay:
   - Sắp xếp tham số theo alphabet
   - URL-encode đúng chuẩn
   - Ký bằng HMAC SHA512 với hashSecret
   - Chèn `vnp_SecureHash`
   - `vnp_Amount = amount * 100`
   - `vnp_CreateDate` / `vnp_ExpireDate` theo GMT+7 yyyyMMddHHmmss
5. Trả về URL thanh toán cho frontend.
6. User thanh toán trên VNPay.
7. VNPay gọi `GET /api/payments/vnpay/return` và `POST /api/payments/vnpay/ipn`.
8. Return URL chỉ hiển thị kết quả; không xác nhận trạng thái.
9. IPN thực hiện verify chữ ký -> kiểm tra đơn hàng -> kiểm tra số tiền -> kiểm tra trạng thái chưa xử lý -> cập nhật `Payment` và `Subscription` -> trả về JSON `RspCode`/`Message` đúng chuẩn VNPay.
10. `Payment.status = PAID`, `Subscription.status = ACTIVE`, `paidAt = now` khi successful.

## Các phương án và chọn lựa
### Phương án A: Dùng `Payment.providerTransactionId` lưu `vnp_TxnRef`
- Ưu điểm: không cần thêm bảng mới; phù hợp với model hiện có.
- Nhược điểm: `providerTransactionId` là dùng chung cho nhiều gateway; cần rõ ràng trong code và audit.
- Chọn: có, vì đúng với yêu cầu thiết kế hiện tại và không tạo bảng mới.

### Phương án B: Tạo bảng `payment_transaction` riêng cho gateway
- Ưu điểm: audit và replay tốt hơn.
- Nhược điểm: vượt phạm vi, phải sửa model và flow lớn hơn; không cần ở thời điểm này.
- Không chọn: vì yêu cầu chỉ cần tích hợp VNPay và không muốn mở rộng scope ngoài quy định.

## Yêu cầu kỹ thuật VNPay áp dụng
- Verify hash: HMAC SHA512 với `hashSecret`
- IDempotency: dựa trên `vnp_TxnRef`/`Payment.providerTransactionId`
- Chỉ cập nhật khi trạng thái chưa xử lý
- `vnp_Amount` phải khớp `amount * 100`
- Dùng `X-Forwarded-For`/`X-Real-IP` khi lấy `vnp_IpAddr`
- Không log secret, chỉ log metadata
- Không dùng Return URL để xác nhận cuối cùng

## Kết luận
- Chọn hướng tích hợp tối thiểu, đúng mô hình hiện có, không đổi kiến trúc nền tảng.
- Sau khi duyệt, triển khai code trong phạm vi VNPay tạo URL + IPN, đồng thời giữ flow `Subscription`/`Payment` đã có.
