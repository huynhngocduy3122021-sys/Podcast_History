# Thanh toán gói CC và ví Listener

Các API dưới đây yêu cầu Bearer token của người dùng tương ứng. Cấu hình `SEPAY_BANK_CODE`,
`SEPAY_BANK_ACCOUNT`, `SEPAY_WEBHOOK_API_KEY` trong `Backend/.env` trước khi tạo checkout chuyển khoản.
SePay phải gọi `POST /api/webhooks/sepay` với header `Authorization: Apikey <SEPAY_WEBHOOK_API_KEY>`.
Không đưa API key này vào frontend.

## Gói hệ thống cho Content Creator

1. `GET /api/creator/system-plans` lấy `planId` của gói trả phí.
2. `POST /api/creator/system-plans/{planId}/subscribe` tạo checkout `PENDING`, trả
   `checkoutId`, `paymentCode`, `qrImageUrl`, `amount`, `expiresAt`.
3. Cho người dùng chuyển khoản đúng số tiền và nội dung trong QR.
4. `GET /api/me/checkouts/{checkoutId}` xem trạng thái. Khi webhook SePay hợp lệ,
   checkout thành `PAID`, đăng ký CC thành `SUCCEEDED` và thời hạn gói bắt đầu từ lúc trả tiền.
5. `GET /api/creator/system-plans/me` lấy quyền lợi hiện có.

## Nạp ví Listener

1. `GET /api/listener/wallet` xem `availableBalance` bằng VND.
2. `POST /api/listener/wallet/top-ups` với `{"amount": 200000}` tạo checkout SePay.
   Chỉ nhận số VND nguyên từ 10.000 đến 100.000.000.
3. `GET /api/me/checkouts/{checkoutId}` xem trạng thái. Chỉ webhook có API key hợp lệ,
   đúng mã và đúng số tiền mới cộng số dư ví. Webhook lặp không cộng thêm lần nữa.

## Listener mua membership của kênh

`POST /api/me/subscriptions` nhận một trong hai body:

```json
{"membershipPlanId":"UUID","paymentMethod":"SEPAY"}
```

```json
{"membershipPlanId":"UUID","paymentMethod":"WALLET"}
```

`SEPAY` là mặc định khi không gửi `paymentMethod`: trả mã/QR, tạo payment và membership
`PENDING`; webhook hợp lệ sẽ chuyển thành `PAID`/`ACTIVE`. Với `WALLET`, backend khóa ví,
kiểm tra số dư, trừ tiền và kích hoạt membership trong cùng một giao dịch database. Nếu
không đủ tiền, toàn bộ giao dịch bị hủy. Xem kết quả qua `GET /api/me/subscriptions` và
`GET /api/me/payments/{paymentId}`.

Checkout chuyển khoản hết hạn sau 30 phút; webhook đến trong 5 phút tiếp theo vẫn được
chấp nhận để xử lý chuyển khoản chậm. Checkout mới cho cùng gói/kênh chỉ được tạo sau
khoảng này. Môi trường không dùng Hibernate `ddl-auto=update` cần chạy migration
`Backend/db/migrations/2026-10-27_checkout_payment.sql` trước khi khởi động bản mới.

Các luồng này chưa tự động chuyển tiền đến tài khoản của Content Creator. Việc chi trả
vẫn theo quy trình quản trị ví và payout hiện có.
