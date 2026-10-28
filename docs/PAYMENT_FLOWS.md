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

## 3. Gói hội viên kênh (Channel Membership Plans) & Luồng đăng ký

### 3.1 Content Creator thiết lập gói hội viên kênh

Creator quản lý và cấu hình gói hội viên của kênh mình qua các bước sau:

1. **Lấy danh sách mẫu gói hội viên (Templates):**
   `GET /api/creator/membership-plans/templates` — token **CREATOR**, không có body.
   Backend trả về danh sách 3 gói mẫu đề xuất (25K, 50K, 75K VND) kèm mô tả, quyền lợi và `templateCode`.

2. **Chọn và kích hoạt một mẫu gói:**
   `PUT /api/creator/membership-plans/templates/{templateCode}/select` — token **CREATOR**, không có body.
   **Backend chỉ để duy nhất một gói `ACTIVE`**, các gói còn lại tự động chuyển sang trạng thái `INACTIVE`.

3. **Tùy chỉnh giá gói đang Active:**
   `PUT /api/creator/membership-plans/{planId}/price` — token **CREATOR**, body:
   ```json
   {
     "price": 30000.00
   }
   ```
   `price` là số dương (VND). Creator có thể điều chỉnh giá bán phù hợp với kênh.

4. **Xem danh sách gói của kênh:**
   `GET /api/creator/membership-plans` — token **CREATOR**, không có body.
   Trả về tất cả các gói thuộc kênh của Creator để theo dõi trạng thái `ACTIVE` / `INACTIVE`.

### 3.2 Listener mua gói hội viên kênh

1. **Lấy gói của kênh:**
   `GET /api/creators/{creatorId}/membership-plans` — token người dùng đã đăng nhập, không có body. `creatorId` là **ID hồ sơ/kênh CC**.
   **Quan trọng:** API này **chỉ trả gói đang `ACTIVE`** để frontend hiển thị nút đăng ký. Mảng rỗng nghĩa là kênh chưa có gói nào được kích hoạt.

2. **Chọn cách thanh toán và tạo subscription:**
   `POST /api/me/subscriptions` — token **LISTENER**; body có `membershipPlanId` và `paymentMethod` là `SEPAY` hoặc `WALLET` (chữ hoa). Nếu bỏ `paymentMethod`, backend mặc định `SEPAY`.

   **Phương thức 1: Chuyển khoản SePay (VietQR)**
   ```json
   {
     "membershipPlanId": "55555555-5555-5555-5555-555555555555",
     "paymentMethod": "SEPAY"
   }
   ```
   HTTP `202 Accepted` trả về:
   ```json
   {
     "subscriptionId": "66666666-6666-6666-6666-666666666666",
     "paymentId": "77777777-7777-7777-7777-777777777777",
     "paymentCode": "DH123456789ABCDE",
     "qrImageUrl": "https://vietqr.app/img?acc=...&bank=...&amount=50000&des=DH123456789ABCDE",
     "amount": 50000.00,
     "currency": "VND",
     "subscriptionStatus": "PENDING",
     "paymentStatus": "PENDING",
     "message": "Đang chờ thanh toán"
   }
   ```
   Frontend hiển thị mã QR, thông tin thanh toán và lưu **`paymentId`**.

   **Polling SePay:**
   Gọi `GET /api/me/payments/{paymentId}` định kỳ (3–5 giây/lần) — token người mua, không có body.
   Response gồm `paymentId`, `subscriptionId`, `paymentCode`, `amount`, `currency`, `paymentStatus`, `subscriptionStatus`, `paidAt`, `expiresAt`.

   | Trạng thái | Frontend xử lý |
   |---|---|
   | `paymentStatus = PENDING` | Tiếp tục giữ modal hiển thị QR và polling |
   | `paymentStatus = PAID` và `subscriptionStatus = ACTIVE` | Dừng polling, thông báo thành công và chuyển trạng thái Hội viên |
   | `paymentStatus = EXPIRED` hoặc `CANCELLED` | Dừng polling, báo giao dịch hết hạn hoặc đã hủy |

   **Phương thức 2: Trừ tiền từ Ví Podcast (Wallet)**
   ```json
   {
     "membershipPlanId": "55555555-5555-5555-5555-555555555555",
     "paymentMethod": "WALLET"
   }
   ```
   Frontend nên gọi `GET /api/listener/wallet` trước để hiển thị số dư khả dụng (`availableBalance`).
   Backend kiểm tra số dư và trừ tiền ngay lập tức:
   - Nếu thành công: HTTP `202 Accepted` có `paymentStatus = PAID`, `subscriptionStatus = ACTIVE`, `paymentCode = null`, `qrImageUrl = null`. Gọi lại `GET /api/me/subscriptions` và `GET /api/listener/wallet` để cập nhật UI.
   - Nếu ví thiếu tiền: Backend trả **`409 Conflict`** (không trừ tiền). Frontend hiển thị thông báo số dư không đủ và nút dẫn tới màn nạp ví.

3. **Xem danh sách gói đã đăng ký:**
   `GET /api/me/subscriptions` — token **LISTENER**, không có body; trả danh sách `subscriptionId`, `membershipPlanId`, `planName`, `creatorProfileId`, `creatorChannelName`, `startAt`, `endAt`, `status`, `autoRenew`, `paymentId`, `paymentStatus`.
   **Chỉ coi là member khi `status = ACTIVE`**.

### 3.3 Chi tiết xử lý lỗi 409 Conflict

Lỗi `409 Conflict` xảy ra trong các trường hợp:
- **Đang có đơn thanh toán chờ xử lý (`PENDING`)**: Người dùng đã tạo đơn SePay trước đó chưa thanh toán và chưa hết hạn.
- **Đã là hội viên đang hoạt động (`ACTIVE`)**: Người dùng đã đăng ký gói của kênh này và thời hạn gói vẫn còn hiệu lực.
- **Số dư ví không đủ (`WALLET`)**: Số dư khả dụng trong ví nhỏ hơn giá niêm yết của gói hội viên.

### 3.4 Thiết kế UI theo từng trạng thái

- **Trạng thái Chưa đăng ký (Non-member):**
  - Hiển thị card gói Active của kênh kèm tên gói, mức giá (định dạng VND), chu kỳ thời hạn (30 ngày) và danh sách quyền lợi (Huy hiệu, nghe podcast riêng).
  - Nút "Tham gia hội viên" mở Bottom Sheet lựa chọn giữa "Chuyển khoản SePay (VietQR)" hoặc "Thanh toán bằng Ví Podcast" (kèm số dư khả dụng hiện tại).
- **Trạng thái Chờ thanh toán (PENDING - SePay):**
  - Hiển thị hộp thoại thanh toán có mã QR ngân hàng (tự động load qua proxy giải quyết CORS trên Web CanvasKit), số tài khoản, số tiền và nội dung chuyển khoản bắt buộc kèm nút copy nhanh.
  - Đồng hồ đếm ngược thời gian thanh toán (30 phút) và vòng quay loading polling ngầm.
  - Nút "Hủy giao dịch" hoặc "Đóng để thanh toán sau".
- **Trạng thái Đã kích hoạt (ACTIVE):**
  - Hiển thị huy hiệu (Badge) "Hội viên kênh" bên cạnh tên người dùng trong bình luận và trên trang kênh của Creator.
  - Hiển thị thời hạn sử dụng gói (`startAt` - `endAt`) và cờ tự động gia hạn (`autoRenew`).
  - Mở khóa ngay lập tức toàn bộ các tập podcast có gắn thẻ `MEMBERS_ONLY` của kênh.
- **Trạng thái Hết hạn / Đã hủy (EXPIRED / CANCELLED):**
  - Tự động thu hồi quyền nghe các tập `MEMBERS_ONLY`.
  - Hiển thị thông báo gói đã hết hạn kèm nút "Đăng ký lại" để tiếp tục ủng hộ Creator.


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
