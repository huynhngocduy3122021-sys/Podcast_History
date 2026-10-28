# API thanh toán để frontend tích hợp

Base URL backend mặc định: `http://localhost:8081`. Android Emulator cần địa chỉ
backend mà emulator truy cập được (thường là `http://10.0.2.2:8081`).
Mọi API người dùng bên dưới gửi:

```http
Authorization: Bearer <accessToken>
Content-Type: application/json
```

Các UUID trong ví dụ chỉ minh họa; lấy ID thật từ response. Số tiền gửi dưới dạng
**số JSON** (ví dụ `200000`), không gửi `"200.000"`. Các luồng này dùng VND.

## 1. Content Creator mua gói hệ thống bằng SePay

### Lấy danh sách gói

`GET /api/creator/system-plans` — token **CREATOR**, không có body.
Response là mảng. Frontend hiển thị `name`, `description`, `price`, `currency`,
`durationDays`, `benefits`; lưu `planId`. Chỉ chọn gói trả phí có `status = ACTIVE`.

```json
[
  {
    "planId": "11111111-1111-1111-1111-111111111111",
    "code": "PLUS",
    "name": "Plus",
    "description": "Gói CC trả phí trong 30 ngày",
    "price": 50000.00,
    "currency": "VND",
    "durationDays": 30,
    "status": "ACTIVE",
    "benefits": [
      {"key": "UPLOAD_LIMIT", "value": "unlimited", "description": "Đăng không giới hạn"},
      {"key": "LIVESTREAM", "value": "true", "description": "Quyền livestream"}
    ]
  }
]
```

### Tạo checkout

`POST /api/creator/system-plans/{planId}/subscribe` — token **CREATOR**,
**không có body**; `planId` lấy từ danh sách gói. HTTP `202 Accepted` trả:

```json
{
  "checkoutId": "22222222-2222-2222-2222-222222222222",
  "creatorSubscriptionId": "33333333-3333-3333-3333-333333333333",
  "purpose": "CREATOR_PLAN",
  "paymentCode": "DH123456789ABCDE",
  "qrImageUrl": "https://vietqr.app/img?acc=...&bank=...&amount=50000&des=DH123456789ABCDE",
  "amount": 50000.00,
  "currency": "VND",
  "status": "PENDING",
  "paidAt": null,
  "expiresAt": "2026-10-27T16:00:00Z"
}
```

Frontend lưu `checkoutId`, hiển thị ảnh `qrImageUrl`, `amount`, `paymentCode`
và thời gian hết hạn. **Chưa báo nâng cấp thành công** khi `status = PENDING`.

### Kiểm tra thanh toán

`GET /api/me/checkouts/{checkoutId}` — token của **chính người tạo checkout**,
không có body; response cùng các trường ở trên.

| `status` | Frontend xử lý |
|---|---|
| `PENDING` | Giữ màn QR, kiểm tra lại sau vài giây |
| `PAID` | Dừng kiểm tra, gọi `GET /api/creator/system-plans/me` |
| `EXPIRED` | Dừng kiểm tra, báo checkout hết hạn |

`GET /api/creator/system-plans/me` — token **CREATOR**, không có body; trả
`planCode`, `planName`, `startAt`, `endAt`, `uploadLimit`, `uploadsUsed`,
`uploadsRemaining`, `canLivestream`, `lastPaymentStatus`, `benefits`.
Gói trả phí chỉ có hiệu lực sau webhook SePay hợp lệ.

## 2. Listener nạp tiền vào ví bằng SePay

### Xem số dư

`GET /api/listener/wallet` — token **LISTENER**, không có body:

```json
{
  "walletId": "44444444-4444-4444-4444-444444444444",
  "availableBalance": 0.00,
  "heldBalance": 0.00,
  "currency": "VND"
}
```

### Nhập số tiền và tạo checkout

`POST /api/listener/wallet/top-ups` — token **LISTENER**, body:

```json
{"amount": 200000}
```

`amount` là số VND nguyên từ **10.000 đến 100.000.000**. HTTP `201 Created`
trả checkout cùng cấu trúc mục 1, nhưng `purpose = WALLET_TOPUP` và
`creatorSubscriptionId = null`. Frontend hiển thị QR và lưu `checkoutId`.

### Xác nhận đã cộng tiền

Gọi `GET /api/me/checkouts/{checkoutId}`. Khi `status = PAID`, gọi lại
`GET /api/listener/wallet` để cập nhật `availableBalance`. Không tự cộng
số dư trên frontend lúc người dùng bấm “Nạp”; backend chỉ cộng sau webhook hợp lệ.

## 3. Listener mua membership của kênh CC

CC không tự tạo ba gói riêng. Backend cung cấp ba mẫu `BASIC_25K`,
`STANDARD_50K`, `PREMIUM_75K`; mỗi kênh chỉ được chọn **một** mẫu để mở bán.
CC dùng `GET /api/creator/membership-plans/templates` để lấy mẫu,
`PUT /api/creator/membership-plans/templates/{templateCode}/select` để chọn,
và `PUT /api/creator/membership-plans/{planId}/price` để đặt giá riêng cho
gói active của kênh. Chi tiết request/response dành cho frontend xem tại
[MEMBERSHIP_PLANS.md](MEMBERSHIP_PLANS.md).

Listener gọi `GET /api/creators/{creatorId}/membership-plans`; API chỉ trả
gói `ACTIVE` đang bán của kênh, nên một kênh bình thường trả tối đa một gói.

### Lấy gói của kênh

`GET /api/creators/{creatorId}/membership-plans` — token người dùng đã đăng nhập,
không có body. `creatorId` là **ID hồ sơ/kênh CC**. Frontend lưu
`membershipPlanId` từ phần tử trả về; mảng rỗng nghĩa là kênh chưa chọn gói
hoặc membership đang tắt.

### Chọn cách thanh toán

`POST /api/me/subscriptions` — token **LISTENER**; body có `membershipPlanId`
và `paymentMethod` là `SEPAY` hoặc `WALLET` (chữ hoa). Nếu bỏ
`paymentMethod`, backend mặc định `SEPAY`.

**Chuyển khoản SePay:**

```json
{
  "membershipPlanId": "55555555-5555-5555-5555-555555555555",
  "paymentMethod": "SEPAY"
}
```

HTTP `202 Accepted` trả `subscriptionId`, `paymentId`, `paymentCode`,
`qrImageUrl`, `amount`, `currency`, `subscriptionStatus = PENDING`,
`paymentStatus = PENDING`, `message`. Frontend hiển thị QR và lưu
**`paymentId`** (khác `checkoutId` ở mục 1–2).

Kiểm tra bằng `GET /api/me/payments/{paymentId}` — token người mua, không có body.
Response gồm `paymentId`, `subscriptionId`, `paymentCode`, `amount`,
`currency`, `paymentStatus`, `subscriptionStatus`, `paidAt`, `expiresAt`.

| Trạng thái | Frontend xử lý |
|---|---|
| `paymentStatus = PENDING` | Tiếp tục chờ |
| `paymentStatus = PAID` và `subscriptionStatus = ACTIVE` | Đã mua thành công |
| `paymentStatus = EXPIRED` hoặc `CANCELLED` | Dừng chờ, báo cần tạo giao dịch mới |

**Trừ tiền ví:**

```json
{
  "membershipPlanId": "55555555-5555-5555-5555-555555555555",
  "paymentMethod": "WALLET"
}
```

Frontend nên gọi `GET /api/listener/wallet` trước để hiển thị số dư; backend vẫn
tự kiểm tra. Nếu thành công, response HTTP `202` có `paymentStatus = PAID`,
`subscriptionStatus = ACTIVE`, `paymentCode = null`, `qrImageUrl = null`.
Gọi lại `GET /api/me/subscriptions` và `GET /api/listener/wallet` để cập nhật UI.
Nếu ví thiếu tiền, backend trả `409 Conflict`; giao dịch không trừ tiền.

`GET /api/me/subscriptions` — token **LISTENER**, không có body; trả danh sách
`subscriptionId`, `membershipPlanId`, `planName`, `creatorProfileId`,
`creatorChannelName`, `startAt`, `endAt`, `status`, `autoRenew`,
`paymentId`, `paymentStatus`. Chỉ coi là member khi `status = ACTIVE`.

## Lỗi, cấu hình và webhook

- `400`: body sai định dạng/giá trị, ví dụ `paymentMethod` khác `SEPAY`/`WALLET`.
- `401`/`403`: thiếu token hoặc sai quyền. `/api/creator/**` dành cho CREATOR;
  `/api/listener/**` dành cho LISTENER.
- `404`: ID gói, payment hoặc checkout không tồn tại/không thuộc người dùng.
- `409`: checkout đang chờ, gói còn hiệu lực, ví thiếu tiền hoặc checkout vừa hết hạn.
- Checkout SePay hết hạn sau **30 phút**. Webhook đến muộn tối đa **5 phút** vẫn
  có thể được xử lý; frontend cần tin trạng thái API thay vì chỉ nhìn đồng hồ.
- Backend cần cấu hình `SEPAY_BANK_CODE`, `SEPAY_BANK_ACCOUNT`,
  `SEPAY_WEBHOOK_API_KEY` trong `Backend/.env`. **Frontend không gọi**
  `POST /api/webhooks/sepay` và không giữ webhook API key; SePay gọi endpoint này.
- Môi trường không dùng Hibernate `ddl-auto=update` cần chạy migration
  `Backend/db/migrations/2026-10-27_checkout_payment.sql` trước khi chạy backend.
- API thanh toán ghi nhận giao dịch và quyền member; việc chuyển tiền tới tài
  khoản ngân hàng của CC vẫn theo quy trình Admin payout riêng.
