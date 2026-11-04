# Membership plans — API contract cho Frontend

Tài liệu này mô tả luồng membership của một kênh CC: CC chọn **một** trong ba gói mẫu, có thể đặt giá riêng cho gói đã chọn; Listener xem gói đang bán và thanh toán bằng SePay hoặc ví.

## Quy ước chung

- Base URL local: `http://localhost:8081`. Android Emulator thường dùng `http://10.0.2.2:8081`.
- API bảo vệ gửi header:

  ```http
  Authorization: Bearer <accessToken>
  Content-Type: application/json
  ```

- UUID trong ví dụ là placeholder; Frontend phải dùng ID từ response thật.
- Backend trả `List`/DTO trực tiếp, không bọc trong `data`.
- Giá là số JSON, đơn vị VND; không gửi chuỗi định dạng tiền (`"50.000"`).

## A. Màn hình CC quản lý gói

### A1. Lấy ba gói mẫu

```http
GET /api/creator/membership-plans/templates
Authorization: Bearer <creatorAccessToken>
```

Chỉ dành cho tài khoản `CREATOR` đã được duyệt. Response luôn gồm ba lựa chọn:

```json
[
  {
    "code": "BASIC_25K",
    "name": "Gói thành viên 25K",
    "suggestedPrice": 25000,
    "currency": "VND",
    "durationDays": 30,
    "benefit": "Member được xem video private của kênh."
  },
  {
    "code": "STANDARD_50K",
    "name": "Gói thành viên 50K",
    "suggestedPrice": 50000,
    "currency": "VND",
    "durationDays": 30,
    "benefit": "Member được xem video private của kênh."
  },
  {
    "code": "PREMIUM_75K",
    "name": "Gói thành viên 75K",
    "suggestedPrice": 75000,
    "currency": "VND",
    "durationDays": 30,
    "benefit": "Member được xem video private của kênh."
  }
]
```

Đây là danh sách mẫu để lựa chọn, **không phải ba gói đang bán cùng lúc**.

### A2. Xem trạng thái gói của kênh

```http
GET /api/creator/membership-plans
Authorization: Bearer <creatorAccessToken>
```

Response là mảng `ChannelPlan`:

```json
[
  {
    "planId": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    "creatorId": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
    "templateCode": "STANDARD_50K",
    "name": "Gói thành viên 50K",
    "description": "Member được xem video private của kênh.",
    "price": 50000,
    "currency": "VND",
    "durationDays": 30,
    "status": "ACTIVE"
  },
  {
    "planId": "cccccccc-cccc-cccc-cccc-cccccccccccc",
    "creatorId": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
    "templateCode": "BASIC_25K",
    "name": "Gói thành viên 25K",
    "description": "Member được xem video private của kênh.",
    "price": 25000,
    "currency": "VND",
    "durationDays": 30,
    "status": "INACTIVE"
  }
]
```

Frontend lấy row có `status = ACTIVE` làm gói đang bán. Backend đảm bảo sau thao tác chọn chỉ có **một** gói active trên kênh; các row `INACTIVE` chỉ là lịch sử/mẫu chưa chọn.

Nếu chưa có row `ACTIVE`, hiển thị màn hình chọn mẫu.

### A3. Chọn một gói mẫu

```http
PUT /api/creator/membership-plans/templates/{templateCode}/select
Authorization: Bearer <creatorAccessToken>
```

`templateCode` chỉ nhận:

- `BASIC_25K`
- `STANDARD_50K`
- `PREMIUM_75K`

Không có request body. Ví dụ:

```http
PUT /api/creator/membership-plans/templates/STANDARD_50K/select
```

Response là `ChannelPlan` của gói vừa chọn, với `status = ACTIVE`.

Khi chọn mẫu mới, backend tự chuyển gói active cũ và các gói khác thành `INACTIVE`. Frontend không cần gọi API deactivate riêng.

### A4. Đặt giá riêng cho gói đang chọn

```http
PUT /api/creator/membership-plans/{planId}/price
Authorization: Bearer <creatorAccessToken>
Content-Type: application/json
```

Body:

```json
{
  "price": 60000
}
```

Điều kiện:

- Chỉ được đổi giá row đang `ACTIVE`.
- Giá là số VND nguyên từ `1000` đến `9999999999`.
- Giá riêng của kênh không thay đổi giá mẫu toàn hệ thống.

Backend giữ row cũ để bảo toàn subscription/payment lịch sử, tạo row active mới và trả về `planId` mới. Frontend phải thay `planId` đang lưu bằng `planId` trong response.

## B. Màn hình Listener xem gói của kênh

### B1. Lấy gói đang bán

```http
GET /api/creators/{creatorId}/membership-plans
Authorization: Bearer <listenerAccessToken>
```

`creatorId` là `creatorProfileId` của kênh, không phải `userId`.

Response chỉ chứa các row `ACTIVE`:

```json
[
  {
    "membershipPlanId": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
    "creatorProfileId": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
    "creatorChannelName": "VietCast Originals",
    "name": "Gói thành viên 50K",
    "description": "Member được xem video private của kênh.",
    "price": 50000,
    "currency": "VND",
    "durationDays": 30
  }
]
```

UI xử lý:

- Mảng có một phần tử: hiển thị nút đăng ký với `membershipPlanId` đó.
- Mảng rỗng: kênh chưa chọn gói hoặc membership đang tắt; ẩn nút mua.
- Không thiết kế UI cho ba gói cùng lúc của một kênh.

## C. Listener đăng ký membership và thanh toán

### C1. Tạo checkout membership

```http
POST /api/me/subscriptions
Authorization: Bearer <listenerAccessToken>
Content-Type: application/json
```

Body bắt buộc:

```json
{
  "membershipPlanId": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "paymentMethod": "SEPAY"
}
```

`paymentMethod` nhận `SEPAY` hoặc `WALLET`. Frontend nên gửi rõ giá trị, không phụ thuộc giá trị mặc định `SEPAY`.

### C2. Thanh toán SePay

Response HTTP `202 Accepted`:

```json
{
  "subscriptionId": "dddddddd-dddd-dddd-dddd-dddddddddddd",
  "paymentId": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
  "paymentCode": "DH123456789ABCDE",
  "qrImageUrl": "https://vietqr.app/img?...",
  "amount": 50000,
  "currency": "VND",
  "subscriptionStatus": "PENDING",
  "paymentStatus": "PENDING",
  "message": "Checkout đã được tạo. Membership chỉ được kích hoạt sau khi SePay xác nhận."
}
```

Frontend:

1. Hiển thị `qrImageUrl`, `amount`, `paymentCode`.
2. Lưu `paymentId` và gọi:

   ```http
   GET /api/me/payments/{paymentId}
   Authorization: Bearer <listenerAccessToken>
   ```

3. Khi `paymentStatus = PAID` và `subscriptionStatus = ACTIVE`, hiển thị đã đăng ký thành công.
4. Khi `paymentStatus = EXPIRED` hoặc `CANCELLED`, dừng polling và cho phép tạo checkout mới.

Không tự chuyển membership sang active chỉ vì người dùng đã mở QR hoặc bấm “đã chuyển khoản”.

### C3. Thanh toán bằng ví

Trước khi mở dialog thanh toán, lấy số dư:

```http
GET /api/listener/wallet
Authorization: Bearer <listenerAccessToken>
```

Tạo checkout bằng ví:

```json
{
  "membershipPlanId": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "paymentMethod": "WALLET"
}
```

Nếu đủ tiền, response `202` có:

```json
{
  "paymentStatus": "PAID",
  "subscriptionStatus": "ACTIVE",
  "paymentCode": null,
  "qrImageUrl": null
}
```

Sau đó gọi lại:

```http
GET /api/me/subscriptions
GET /api/listener/wallet
```

Nếu ví không đủ tiền, backend trả `409 Conflict` và không trừ tiền.

### C4. Danh sách membership của Listener

```http
GET /api/me/subscriptions
Authorization: Bearer <listenerAccessToken>
```

Chỉ coi Listener là member khi `status = ACTIVE`. Response gồm `subscriptionId`, `membershipPlanId`, `planName`, `creatorProfileId`, `creatorChannelName`, `startAt`, `endAt`, `status`, `autoRenew`, `paymentId`, `paymentStatus`.

Hủy subscription:

```http
DELETE /api/me/subscriptions/{subscriptionId}
Authorization: Bearer <listenerAccessToken>
```

## D. Các lỗi Frontend cần xử lý

| HTTP | Ý nghĩa thường gặp |
|---:|---|
| `400` | Body sai, UUID sai hoặc `paymentMethod` không phải `SEPAY/WALLET` |
| `401` | Access token hết hạn; refresh token rồi gọi lại một lần |
| `403` | Sai role hoặc CC chưa được duyệt |
| `404` | Không tìm thấy kênh/gói/payment hoặc gói không còn active |
| `409` | Đã có checkout pending, đã là member, ví thiếu tiền, checkout vừa hết hạn hoặc đổi giá sai row |

Frontend không gọi `POST /api/webhooks/sepay`; endpoint này chỉ dành cho SePay gọi bằng webhook API key.

## E. Flow UI đề xuất

### CC

1. Mở màn hình: gọi `GET /api/creator/membership-plans/templates` và `GET /api/creator/membership-plans`.
2. Nếu có row `ACTIVE`, hiển thị gói đó và nút sửa giá.
3. Nếu chưa có row `ACTIVE`, cho chọn một trong ba mẫu.
4. Khi chọn mẫu, gọi `PUT .../templates/{templateCode}/select`.
5. Khi sửa giá, gọi `PUT .../{planId}/price` và cập nhật `planId` mới từ response.

### Listener

1. Mở trang kênh: gọi `GET /api/creators/{creatorId}/membership-plans`.
2. Nếu response có một gói, hiển thị giá và hai lựa chọn `SEPAY`/`WALLET`.
3. Gọi `POST /api/me/subscriptions` với `membershipPlanId`.
4. Với SePay, polling `GET /api/me/payments/{paymentId}` cho tới `PAID/ACTIVE`, hoặc hết hạn.
5. Với Wallet, sau response thành công gọi lại subscriptions và wallet để refresh UI.
