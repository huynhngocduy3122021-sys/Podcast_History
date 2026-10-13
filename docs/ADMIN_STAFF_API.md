# Admin và Staff — chức năng quản trị

Cập nhật 13/10/2026. Tài liệu mô tả code mới; cần khởi động lại backend để Swagger và schema được cập nhật. Các ví dụ UUID phải thay bằng ID thật.

## 1. Phân quyền

| Chức năng | ADMIN | STAFF |
|---|---|---|
| Dashboard tổng hợp | Có | Có |
| Xem, preview video/PDF, duyệt/từ chối, ẩn nội dung | Có | Có |
| Nhận/xử lý report, khiếu nại podcast | Có | Có |
| Duyệt đăng ký Creator | Có | Không |
| Quản lý user, xác minh, khóa/mở, đổi role, tạo Staff | Có | Không |
| Tạo/sửa/tắt category và membership-plan | Có | Không |
| Hợp đồng/tranh chấp, đối soát thanh toán, hoàn tiền, ví/rút tiền | Có | Không |
| Audit log tổng thể | Có | Không |

Staff dùng `/api/staff/...` cho dashboard, podcasts, reports, podcast-appeals và nguồn podcast. Admin dùng `/api/admin/...`. STAFF không được gọi các URL Admin dù nghiệp vụ tương tự. Mọi request gửi `Authorization: Bearer <accessToken>`.

Không có API tự cấp thêm ADMIN. Tài khoản Admin hiện tại không được khóa/đổi role qua các API user để giữ tài khoản quản trị duy nhất. Đổi role CREATOR chỉ được phép khi profile đã APPROVED; luồng xét duyệt chính vẫn là creator-applications.

## 2. Khởi động và database

Chạy trong thư mục Backend:

```powershell
mvn spring-boot:run
```

Nếu backend cũ vẫn đang chạy trong terminal, Ctrl+C trong terminal đó rồi chạy lại lệnh. Tiến trình đang chạy không tự cập nhật từ bản build mới. Swagger: `http://localhost:8081/swagger-ui/index.html`.

Với `spring.jpa.hibernate.ddl-auto=update` hiện tại, khi khởi động lại Hibernate tạo các bảng/cột bổ sung. Có migration tương đương `Backend/db/migrations/2026-10-13_admin_operations.sql` cho môi trường cần quản lý schema thủ công/validate. Migration thêm dữ liệu cấu trúc, không xóa bảng hoặc dữ liệu cũ.

Schema bổ sung:

- `Admin_audit`: actor, action, resource, note, thời gian.
- `Podcast_appeal`: khiếu nại của chủ kênh và kết quả xử lý.
- `Contract_dispute`: tranh chấp hợp đồng và kết luận.
- `User.token_version`: thu hồi access token bằng phiên bản.
- `User.row_version`: tránh ghi đè role/trạng thái khi đăng nhập và quản trị diễn ra đồng thời.
- `Podcast.row_version`: chống ghi đè dữ liệu đồng thời.
- `Report.assigned_to_id`: người đang xử lý.
- `Withdrawal_request.funds_reserved/payout_reference`: tiền đang giữ và mã chuyển khoản.
- `Payment.refund_reference/refunded_at`: đối soát hoàn tiền thủ công.

Không tự gán funds_reserved=true cho yêu cầu rút tiền cũ. Những yêu cầu PROCESSING từ dữ liệu import chưa có transaction giữ tiền cần được đối soát thủ công trước; API không tự đoán số tiền đã trừ.

CORS local cho localhost/127.0.0.1 đã cấu hình. Frontend deploy ở domain khác: thêm `APP_CORS_ALLOWED_ORIGINS=https://frontend.example.com,http://localhost:*` vào `.env` rồi restart. CORS bucket R2 là cấu hình riêng trên Cloudflare.

## 3. Dashboard và tài khoản

| Method | API | Body / kết quả |
|---|---|---|
| GET | `/api/admin/dashboard` | Tổng users/active, Creator, podcast/status, pending report/withdrawal, open dispute, tổng payments đã thu theo currency |
| GET | `/api/admin/users?q=&role=&active=&page=0&size=20` | Page user, không trả password hash hoặc token |
| GET | `/api/admin/users/{userId}` | Chi tiết user |
| PATCH | `/api/admin/users/{userId}` | displayName, avatarUrl, bio |
| PATCH | `/api/admin/users/{userId}/access` | `{ "active": false, "note": "Lý do khóa" }` |
| PATCH | `/api/admin/users/{userId}/verification` | `{ "verified": true, "note": "Đã kiểm tra hồ sơ" }` |
| PATCH | `/api/admin/users/{userId}/role` | `{ "role": "STAFF", "note": "Phân công xử lý nội dung" }` |
| POST | `/api/admin/users/{userId}/revoke-sessions` | `{ "note": "Thu hồi phiên" }` |
| GET | `/api/admin/staff` | Page Staff |
| POST | `/api/admin/staff` | username, email, password, displayName; 201 |
| GET | `/api/admin/audit-logs?resourceType=&resourceId=` | Page hành động quản trị |

Khóa/mở user, đổi role và revoke-sessions tăng token_version, thu hồi refresh token; JWT cũ bị từ chối. JWT decoder kiểm tra trạng thái user/role/version hiện tại, issuer và token_type. Refresh không cấp token cho user inactive. Client cần login lại sau thay đổi role/phiên; JWT validation có một truy vấn user cho mỗi request bảo vệ để quyền thay đổi có hiệu lực ngay.

Dashboard `collectedPayments` là tổng payment PAID/SUCCESS/COMPLETED theo tiền tệ, không phải lợi nhuận nền tảng hay số dư có thể rút. Không cộng các currency khác nhau thành một số.

## 4. Duyệt Creator và podcast

API approve/reject Creator hiện có vẫn dùng như trước. Bổ sung:

- GET `/api/admin/creator-applications?status=PENDING&page=0&size=20`: mọi profile theo trạng thái, phân trang.
- GET `/api/admin/creator-applications/{applicationId}`: chi tiết hồ sơ.
- Approve/reject ghi audit và Notification cho người gửi. Sau APPROVED, Listener refresh/login lại để nhận role CREATOR.

Prefix nội dung: **A = /api/admin/podcasts**; Staff thay bằng **/api/staff/podcasts**.

| Method | API | Ý nghĩa |
|---|---|---|
| GET | `A` | List cũ giữ nguyên để không phá client |
| GET | `A/page?status=PENDING_REVIEW&page=0&size=20` | Danh sách phân trang; ưu tiên dùng endpoint này cho giao diện mới |
| GET | `A/pending-review` | Hàng đợi List cũ |
| GET | `A/{podcastId}` | Metadata và 20 quyết định gần nhất |
| GET | `A/{podcastId}/preview` | videoUrl có chữ ký, expiresAt, hiệu lực 5 phút; được xem bản chờ duyệt/ẩn |
| GET | `A/{podcastId}/reviews` | Lịch sử moderation phân trang |
| GET | `A/{podcastId}/references` | Nguồn tham khảo |
| GET | `A/{podcastId}/references/{referenceId}/file` | PDF downloadUrl có chữ ký |
| POST | `A/{podcastId}/approve` | PENDING_REVIEW → APPROVED, note tùy chọn |
| POST | `A/{podcastId}/reject` | PENDING_REVIEW → REJECTED, note bắt buộc |
| POST | `A/{podcastId}/hide` | `{ "note": "Lý do ẩn" }`, 204, trạng thái HIDDEN |
| DELETE | `A/{podcastId}` | `{ "note": "Lý do gỡ" }`, 204, xóa mềm DELETED |
| POST | `A/{podcastId}/restore` | HIDDEN → PENDING_REVIEW, note bắt buộc; phải approve lại để xuất bản |

Thứ tự: GET page → GET detail → GET preview/PDF → approve hoặc reject. Quyết định khóa record và ghi Moderation_Review/audit/Notification. Optimistic version giúp phát hiện cập nhật Creator xung đột.

**Storage:** Preview quản trị luôn dùng URL ký. Để hide/MEMBERS_ONLY có ý nghĩa bảo vệ, video/PDF phải ở R2 private hoặc có lớp authorization trên domain. Nếu bật public access cho cùng bucket, URL công khai đã biết vẫn có thể truy cập trực tiếp. API hide ngăn cấp link qua Listener, không tự đổi cấu hình bucket Cloudflare hoặc thu hồi một URL ký đã cấp còn hạn.

## 5. Report và khiếu nại

Prefix **M = /api/admin**, Staff dùng **/api/staff**.

1. GET `M/reports?status=PENDING&page=0&size=20` → GET `M/reports/{reportId}`.
2. POST `M/reports/{reportId}/claim` để nhận xử lý, trạng thái UNDER_REVIEW. Staff khác không được ghi đè người nhận; Admin được nhận lại.
3. POST `M/reports/{reportId}/resolve`:

```json
{"action":"HIDE_CONTENT","note":"Nội dung vi phạm, tạm ẩn để xem xét"}
```

action: DISMISS (bác bỏ → DISMISSED), HIDE_CONTENT hoặc DELETE_CONTENT (xử lý → RESOLVED). Podcast và comment đều hỗ trợ; livestream chưa triển khai endpoint xử lý nội dung. Quyết định lưu Moderation_Review, thông báo người báo cáo và chủ nội dung. Report đã kết thúc không được resolve lại.

Creator bị reject/ẩn có thể gửi POST `/api/creator/podcasts/{podcastId}/appeals` với `{ "note": "Lý do khiếu nại" }`, xem GET cùng đường dẫn và GET `/api/creator/podcasts/{podcastId}/reviews` để đọc lý do/lịch sử xét duyệt.

- GET `M/podcast-appeals?status=PENDING`: hàng đợi khiếu nại.
- GET `M/podcast-appeals/{appealId}`: chi tiết.
- POST `M/podcast-appeals/{appealId}/resolve`: `{ "decision": "ACCEPT", "note": "Cần xem xét lại" }` hoặc REJECT.
- ACCEPT đưa podcast HIDDEN/REJECTED có video về PENDING_REVIEW, không tự công khai. Chỉ một khiếu nại PENDING/podcast; dữ liệu được khóa khi tạo/xử lý.

## 6. Gói thành viên và đối soát thanh toán thủ công

Admin CRUD `/api/admin/membership-plans`:

- GET list (creatorId/status/page/size), GET `/{planId}`.
- POST create (201), PUT `/{planId}`, DELETE `/{planId}` với note để INACTIVE.

```json
{
  "creatorId":"<UUID Creator_profile>",
  "name":"Thành viên kênh",
  "description":"Nghe nội dung độc quyền và gửi yêu cầu",
  "price":50000,
  "currency":"VND",
  "durationDays":30,
  "status":"ACTIVE"
}
```

Kênh phải được duyệt/hoạt động. Gói đã có checkout/subscription không được đổi giá/currency/duration; tạo gói mới để không làm sai giao dịch đang chờ hoặc đã mua. Tắt gói không xóa subscription đang còn hiệu lực.

Listener lấy membership-plans, POST /api/me/subscriptions như trước. Admin:

| Method | API | Ý nghĩa |
|---|---|---|
| GET | `/api/admin/payments?status=PENDING` | Phân trang thanh toán |
| GET | `/api/admin/payments/{paymentId}` | Chi tiết và mã đối soát/refund |
| POST | `/api/admin/payments/{paymentId}/reconcile` | Ghi nhận kết quả đối soát chuyển khoản |
| POST | `/api/admin/payments/{paymentId}/refund` | Ghi nhận hoàn toàn bộ tiền đã thực hiện bên ngoài |

```json
{"result":"PAID","providerTransactionId":"BANK-20261013-001","note":"Đã đối chiếu giao dịch ngân hàng"}
```

Chỉ Admin ghi nhận PAID/FAILED cho payment PENDING. PAID yêu cầu mã giao dịch chưa dùng. Membership PENDING được chuyển ACTIVE, startAt là lúc đối soát và endAt tính theo durationDays. Nếu đã có ACTIVE cùng kênh hoặc gói/user không hợp lệ, trả 409 để đối soát checkout trùng, không tự cộng gói hoặc bỏ kiểm tra.

Đối với contract-stage, chỉ ghi PAID sau khi mốc APPROVED/COMPLETED và hợp đồng đang hoạt động/hoàn thành, không đang tranh chấp. Thanh toán không tự release funds vào ví.

Refund body: `{ "refundReference": "BANK-REFUND-001", "note": "Đã chuyển trả toàn bộ tiền" }`. Chỉ payment đã thu; chuyển REFUNDED, hủy subscription nếu có và lưu reference/refundedAt. Nếu payment đã có giao dịch giải ngân COMPLETED trong ví, cần xử lý đối soát thu hồi trước; API từ chối hoàn tiền làm mất cân đối.

**Các endpoint này chỉ ghi nhận sự kiện ngân hàng đã được Admin xác minh, không gửi lệnh chuyển tiền tới ngân hàng. Không có webhook/gateway tự động, partial refund hoặc tự thu hồi tiền đã giải ngân.**

## 7. Duyệt rút tiền và ghi nhận chuyển khoản

1. GET `/api/admin/withdrawals?status=PENDING` → GET `/{withdrawalId}`.
2. Xác minh số dư/đúng ví, currency, người nhận và thông tin tài khoản nhận ở nguồn thanh toán thực tế. DB chỉ có payoutAccountMasked; không thể tự xác minh số tài khoản ngân hàng đầy đủ từ field này.
3. POST `/api/admin/withdrawals/{withdrawalId}/approve`:

```json
{"payoutAccountVerified":true,"note":"Đã kiểm tra thông tin nhận tiền"}
```

Khóa request + wallet; trừ số dư khả dụng để giữ tiền, tạo Wallet_Transaction WITHDRAWAL OUT PENDING; request → PROCESSING, fundsReserved=true. Thiếu số dư, sai ví/currency, account không hợp lệ trả 409. Không tự chuyển tiền bên ngoài.

4. Nếu không chấp nhận request PENDING: POST `.../reject` với note; không trừ tiền.
5. Sau khi chuyển khoản thủ công thành công, POST `.../complete`:

```json
{"payoutReference":"BANK-PAYOUT-001","note":"Đã chuyển khoản và đối chiếu thành công"}
```

Request → COMPLETED, fundsReserved=false; transaction PENDING → COMPLETED. Không trừ số dư lần nữa. Payout reference duy nhất.

6. Nếu chuyển khoản thất bại, POST `.../fail` với note: hoàn số tiền đang giữ vào số dư khả dụng; request/transaction → FAILED. Chỉ PROCESSING có fundsReserved và transaction PENDING mới được complete/fail; gọi lại sau kết thúc trả 409, không hoàn tiền/trừ tiền lần hai.

GET `/api/admin/withdrawals/{withdrawalId}/reviews`: lịch sử quyết định. GET `/api/admin/wallets`: ví/số dư khả dụng. GET `/api/admin/wallet-transactions?walletId=&status=`: giao dịch.

`balance` là số dư khả dụng; khi đang xử lý rút tiền nó đã giảm. Transaction PENDING biểu diễn tiền đang giữ, không phải khoản đã chuyển thành công. Khi fail, cập nhật cùng transaction FAILED và số dư đã hoàn; không tạo thêm transaction IN khiến cộng trùng tiền trong báo cáo. Audit/Withdrawal_review ghi thời điểm và kết quả hoàn giữ.

Luồng CC tạo ví/yêu cầu rút tiền và Release Funds chưa nằm trong lượt triển khai Admin này; API quản trị làm việc với các bản ghi nghiệp vụ đang có trong DB. Không seed số dư hoặc tạo giao dịch giả để minh họa.

## 8. Hợp đồng và tranh chấp

- GET `/api/admin/contracts?status=&page=&size=` và GET `/{contractId}` để xem hợp đồng/mốc.
- Người tham gia gửi POST `/api/contracts/{contractId}/disputes` với note; xem GET `/api/me/disputes`.
- Admin có thể mở hồ sơ qua POST `/api/admin/contracts/{contractId}/disputes`.
- Mở hồ sơ lưu trạng thái cũ, đổi contract → DISPUTED; không cho hai hồ sơ OPEN cùng contract.
- GET `/api/admin/disputes?status=OPEN`, GET `/{disputeId}`.
- POST `/api/admin/disputes/{disputeId}/resolve`:

```json
{"decision":"RESUME_CONTRACT","note":"Hai bên thống nhất tiếp tục thực hiện"}
```

RESUME_CONTRACT trả về trạng thái cũ. CANCEL_CONTRACT yêu cầu xử lý/hoàn các payment đã thu trước rồi hủy hợp đồng/mốc. COMPLETE_CONTRACT yêu cầu có các mốc và tất cả đã APPROVED/COMPLETED. Kết luận ghi note, reviewer, thời gian, audit và notification cho hai bên. Không tự giải ngân/hoàn tiền từ một quyết định tranh chấp.

Luồng Creator tạo/chấp nhận đơn, tạo hợp đồng, bàn giao và duyệt mốc vẫn cần phát triển ở phần CC/Listener; Admin quản lý hồ sơ hiện hữu và tranh chấp, không giả lập các bước đó.

## 9. Thông báo và kiểm tra triển khai

- GET `/api/me/notifications?page=0&size=20`.
- PUT `/api/me/notifications/{notificationId}/read`, 204; chỉ thông báo của chính mình.

Thông báo lưu trong DB, chưa gửi email hoặc push Firebase. AI moderation chưa triển khai theo yêu cầu.

Đã build và chạy bộ HTTP regression: 664/664 kiểm tra đạt, 163/163 endpoint có lượt gọi 2xx trên DB riêng và R2 giả lập. Xem [báo cáo kiểm thử](API_REGRESSION_RESULTS_2026-10-13.md); chưa benchmark tải hoặc test R2/ngân hàng thật. Cần restart backend và đăng nhập lại trước khi dùng Swagger cho các endpoint mới; chỉ compile/build không cập nhật tiến trình đang chạy.

