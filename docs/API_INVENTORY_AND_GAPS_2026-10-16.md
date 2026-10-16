# Kiểm kê API backend — 16/10/2026

> Đây là ảnh chụp kiểm kê trước khi thêm poll. Sau đó đã bổ sung 16 API poll một câu hỏi/nhiều option; xem [POLL_API.md](POLL_API.md). Các nhận định bên dưới về poll chưa có API là trạng thái tại thời điểm kiểm kê.

## Phạm vi và kết quả

Đọc controller/service của code local trên nhánh NgocDuy tại commit `9af4456`, đối chiếu với `/v3/api-docs` của backend đang chạy ở localhost:8081. Chưa fetch/merge thêm nhánh dev, chưa chạy lại kiểm thử mutation hoặc benchmark trong lượt kiểm kê này.

- **176 operation, 27 controller**. Operation = phương thức HTTP + đường dẫn.
- **Code và OpenAPI đang chạy khớp 176/176**, không phát hiện mapping trùng.
- Admin: **67**; Staff: **21**; Creator: **30**; Auth: **5**; Listener/chung: **53**.
- Có 21 route Staff dùng chung xử lý với Admin; 176 route không tương đương 176 chức năng độc lập. Nhóm Listener/chung gồm cả health, categories, hồ sơ xin Creator và upload.
- Có route/model không đồng nghĩa toàn bộ nghiệp vụ đã hoàn thành. Phần thiếu bên dưới được xác định bằng đọc service và đối chiếu PRODUCT_FLOWS.

## Các phần đã có

| Nhóm | Phạm vi API |
| --- | --- |
| Auth | Register, login, refresh, logout, me; BCrypt, JWT 10 phút/refresh 7 ngày, rotation và thu hồi phiên |
| Catalog/Listener | Tìm/lọc/phân trang, chi tiết podcast/kênh, playback, lịch sử/progress, like, follow, saved podcasts |
| Comment/report | Tạo/list/sửa/xóa comment, mốc video timestampSeconds, SSE comment-created; tạo/list/sửa/rút report |
| Thành viên kênh | Danh sách gói, tạo checkout PENDING, theo dõi/hủy subscription; Admin CRUD gói, đối soát/hoàn tiền thủ công |
| Đăng ký Creator | Gửi/xem hồ sơ của mình; Admin xem/lọc/duyệt/từ chối; lưu Creator_profile |
| CC xuất bản | CRUD podcast/series, gắn/gỡ series, upload video gắn podcast, nguồn tham khảo/PDF optional, gửi duyệt, xem review/khiếu nại |
| Podcast theo yêu cầu | Listener gửi/list, CC nhận/từ chối và tạo các mốc, upload bản bàn giao, Listener approve/yêu cầu sửa, tranh chấp mốc |
| Admin/Staff | Dashboard, duyệt/preview/review podcast, hide/restore/delete, claim/resolve report, xử lý appeal; Staff có route riêng |
| Admin tài khoản | Danh sách/chi tiết/sửa/khóa/xác minh/đổi role/thu hồi phiên, tạo Staff, audit log |
| Admin tài chính | Xem payment/ví/giao dịch/yêu cầu rút; reconcile/refund; approve/reject/complete/fail yêu cầu rút |
| Admin tranh chấp | Quản lý hợp đồng/tranh chấp hợp đồng; tranh chấp mốc có namespace riêng |
| Thông báo | List notification của mình và đánh dấu đã đọc |

## Thiếu hoặc mới hoàn thành một phần

Các endpoint nêu trong cột cuối là **đề xuất, chưa tồn tại**, không phải URL có thể gọi ngay.

| Mức | Phần thiếu | Hiện trạng/ảnh hưởng | API hoặc công việc đề xuất |
| --- | --- | --- | --- |
| P1 | Ví của Creator và release funds | Chỉ có API Admin xem/xử lý rút tiền. Chưa có API CC xem ví/giao dịch, gửi/hủy/xem yêu cầu rút hoặc tài khoản nhận tiền; chưa thấy đường ghi thu nhập PAID vào ví trong service. | GET `/api/creator/wallet`, GET `/api/creator/wallet/transactions`, POST `/api/creator/wallet/release-funds`, GET/POST `/api/creator/withdrawals`, CRUD `/api/creator/bank-accounts`; khóa tiền, idempotency và đối soát số dư |
| P1 | Chưa nối trọn payment theo mốc | Duyệt mốc tạo Payment PENDING; khi mọi mốc APPROVED, contract thành AWAITING_PAYMENT. Admin reconcile hiện chỉ cho contract ACTIVE/IN_PROGRESS/COMPLETED, nên mốc cuối có thể bị 409. Payment PAID chưa kéo theo cập nhật hoàn tất hợp đồng/ghi thu nhập Creator. | Sửa state machine của API reconcile hiện có; nối Payment → Stage → Contract → Wallet. Đây là lỗi tích hợp cần sửa, không chỉ thêm endpoint. |
| P1 | Xem/phát file bàn giao private | GET submissions có objectKey/publicUrl. Upload milestone cố ý không trả URL public; service đọc lại publicUrl đã lưu, chưa có bước cấp signed URL cho file này. | GET `/api/milestones/{milestoneId}/submissions/{submissionId}/playback` hoặc cấp URL ký trong response sau kiểm tra bên liên quan |
| P1 | Danh sách đơn của CC sau khi nhận | GET `/api/creator/requests/incoming` chỉ lọc PENDING. Chưa có danh sách đã nhận/đang làm/hoàn tất hoặc GET chi tiết đơn theo ID cho CC. GET `/api/requests/{id}/milestones` đã có nhưng cần biết ID trước. | GET `/api/creator/requests?status=...`, GET `/api/creator/requests/{requestId}`; thống nhất dữ liệu với API request cũ |
| P2 | Hồ sơ cá nhân và mật khẩu | GET auth/me đọc được; Admin sửa được tài khoản. Chưa có API user tự sửa profile/avatar/bio, đổi mật khẩu, quên/reset mật khẩu hoặc xác minh email OTP. | PATCH `/api/me/profile`, PUT `/api/me/password`, POST forgot/reset-password và email verification nếu sản phẩm cần |
| P2 | Premium dành cho CC | Membership kênh đã có, nhưng không phải Creator Premium. Chưa có billing Premium, entitlement hoặc quota đăng theo gói. | API plan/subscription Premium của Creator và kiểm tra quyền/quota |
| P2 | Biểu mẫu/poll | Có model Poll/PollOption/PollVote, chưa có controller nghiệp vụ tương ứng. | CRUD `/api/creator/forms` hoặc polls; listener trả lời và CC xem kết quả |
| Bổ sung | Playlist đặt tên | Saved podcasts đã có. Chưa có nhiều playlist có tên, sắp xếp/thêm/xóa từng mục. | CRUD `/api/me/playlists` và items nếu cần playlist riêng ngoài favorites |
| Bổ sung | Quản lý kênh/analytics | CC đọc podcast/series được; thông tin kênh đọc qua API creators. Chưa có API CC cập nhật kênh/dashboard thống kê của chính kênh. | GET/PATCH `/api/creator/profile`, GET `/api/creator/dashboard` |
| Bổ sung | Bình luận nâng cao | CRUD/SSE/mốc đã có. Chưa có reply lồng nhau, ghim hoặc API CC tự ẩn bình luận; Admin xử lý report là luồng khác. | Replies/pin/hide nếu muốn bật các nút tương ứng của giao diện CC |
| Bổ sung | Quản lý gói hội viên bởi CC | Admin đang có CRUD membership plans; CC chưa tự CRUD gói. Không bắt buộc nếu chính sách để Admin quản lý gói. | `/api/creator/membership-plans` nếu cho CC tự định giá/quản lý |
| Tùy chọn | Cổng thanh toán online | Đã có reconcile/refund thủ công theo phương án được duyệt. Chưa có payment gateway/webhook có kiểm tra chữ ký. Subscription đã trả payment status, nhưng chưa có API payment cá nhân riêng. | Chỉ thêm gateway/webhook khi chuyển sang thanh toán tự động; có thể bổ sung `/api/me/payments` cho lịch sử chi tiết |
| Đang hoãn | Livestream/AI moderation | Chưa có API livestream và AI. AI trước đó được yêu cầu hoãn; không tính là API Admin cần làm ngay. | Tách thành giai đoạn riêng, không đánh dấu đã hoàn thành chỉ vì có model |

### Bằng chứng code cho các điểm P1

- `service/PodcastRequestService.java`: `createPendingPayment`, `updateContractStatusIfAllApproved`, `getCreatorInbox`, `toSubmissionResponse`.
- `service/AdminFinanceService.java`: `reconcile` kiểm tra contract ACTIVE/IN_PROGRESS/COMPLETED; `approve/fail` chỉ giữ/hoàn tiền rút, không phải release thu nhập.
- `service/MediaUploadService.java`: `uploadMilestoneMedia` lưu object key private, publicUrl null.
- Không tìm thấy service tạo UserWallet hoặc cộng thu nhập vào ví từ Payment PAID; cộng tiền trong fail withdrawal là hoàn lại khoản giữ.

### Thứ tự hoàn thiện đề nghị

1. Sửa state machine thanh toán mốc và cấp URL file bàn giao private.
2. Bổ sung CC xem lại các đơn đã nhận/chi tiết đơn.
3. Hoàn thành thu nhập → ví → yêu cầu rút → Admin duyệt.
4. Self profile/password, rồi Creator Premium và forms.
5. Các tính năng tùy chọn (playlist nâng cao, analytics, thanh toán tự động), livestream/AI theo phạm vi được duyệt.

## Hai nhóm API request cần thống nhất

Hiện tồn tại song song POST `/api/creators/{creatorId}/series-requests` cùng GET/PUT/DELETE `/api/me/series-requests/...` (luồng cũ có kiểm tra membership) và POST `/api/requests` cùng các API milestones (luồng mới). Đây không phải mapping trùng, nhưng dùng hai DTO và quy tắc khác nhau. Frontend cần chọn một luồng chuẩn, tránh dùng URL `/api/v1/...` trong tài liệu FE như thể đó là route backend hiện tại.

## Danh sách đầy đủ 176 operation

Các path trong phần này là route hiện có. Quyền ở mức handler còn phụ thuộc ownership/trạng thái; GET public duy nhất cho category và các endpoint Auth/health/Swagger đã được khai báo công khai. Các API nghiệp vụ còn lại yêu cầu JWT, với /admin, /staff, /creator, /listener theo role.

### AdminCategoryController.java

| Method | Path |
| --- | --- |
| GET | `/api/admin/categories` |
| GET | `/api/admin/categories/{categoryId}` |
| POST | `/api/admin/categories` |
| PUT | `/api/admin/categories/{categoryId}` |
| DELETE | `/api/admin/categories/{categoryId}` |

### AdminContentController.java

| Method | Path |
| --- | --- |
| GET | `/api/admin/reports` |
| GET | `/api/staff/reports` |
| GET | `/api/admin/reports/{reportId}` |
| GET | `/api/staff/reports/{reportId}` |
| POST | `/api/admin/reports/{reportId}/claim` |
| POST | `/api/staff/reports/{reportId}/claim` |
| POST | `/api/admin/reports/{reportId}/resolve` |
| POST | `/api/staff/reports/{reportId}/resolve` |
| POST | `/api/admin/podcasts/{podcastId}/hide` |
| POST | `/api/staff/podcasts/{podcastId}/hide` |
| DELETE | `/api/admin/podcasts/{podcastId}` |
| DELETE | `/api/staff/podcasts/{podcastId}` |
| POST | `/api/admin/podcasts/{podcastId}/restore` |
| POST | `/api/staff/podcasts/{podcastId}/restore` |
| GET | `/api/admin/podcast-appeals` |
| GET | `/api/staff/podcast-appeals` |
| GET | `/api/admin/podcast-appeals/{appealId}` |
| GET | `/api/staff/podcast-appeals/{appealId}` |
| POST | `/api/admin/podcast-appeals/{appealId}/resolve` |
| POST | `/api/staff/podcast-appeals/{appealId}/resolve` |

### AdminCreatorApplicationController.java

| Method | Path |
| --- | --- |
| GET | `/api/admin/creator-applications/pending` |
| GET | `/api/admin/creator-applications` |
| GET | `/api/admin/creator-applications/{applicationId}` |
| POST | `/api/admin/creator-applications/{applicationId}/approve` |
| POST | `/api/admin/creator-applications/{applicationId}/reject` |

### AdminDashboardController.java

| Method | Path |
| --- | --- |
| GET | `/api/admin/dashboard` |
| GET | `/api/staff/dashboard` |

### AdminDisputeController.java

| Method | Path |
| --- | --- |
| GET | `/api/admin/contracts` |
| GET | `/api/admin/contracts/{contractId}` |
| POST | `/api/admin/contracts/{contractId}/disputes` |
| GET | `/api/admin/disputes` |
| GET | `/api/admin/disputes/{disputeId}` |
| POST | `/api/admin/disputes/{disputeId}/resolve` |

### AdminFinanceController.java

| Method | Path |
| --- | --- |
| GET | `/api/admin/withdrawals` |
| GET | `/api/admin/withdrawals/{withdrawalId}` |
| GET | `/api/admin/withdrawals/{withdrawalId}/reviews` |
| POST | `/api/admin/withdrawals/{withdrawalId}/approve` |
| POST | `/api/admin/withdrawals/{withdrawalId}/reject` |
| POST | `/api/admin/withdrawals/{withdrawalId}/complete` |
| POST | `/api/admin/withdrawals/{withdrawalId}/fail` |
| GET | `/api/admin/wallets` |
| GET | `/api/admin/wallet-transactions` |
| GET | `/api/admin/payments` |
| GET | `/api/admin/payments/{paymentId}` |
| POST | `/api/admin/payments/{paymentId}/reconcile` |
| POST | `/api/admin/payments/{paymentId}/refund` |

### AdminMembershipPlanController.java

| Method | Path |
| --- | --- |
| GET | `/api/admin/membership-plans` |
| GET | `/api/admin/membership-plans/{planId}` |
| POST | `/api/admin/membership-plans` |
| PUT | `/api/admin/membership-plans/{planId}` |
| DELETE | `/api/admin/membership-plans/{planId}` |

### AdminMilestoneDisputeController.java

| Method | Path |
| --- | --- |
| GET | `/api/admin/milestone-disputes/open` |
| POST | `/api/admin/milestone-disputes/{disputeId}/resolve` |

### AdminPodcastReferenceController.java

| Method | Path |
| --- | --- |
| GET | `/api/admin/podcasts/{podcastId}/references` |
| GET | `/api/staff/podcasts/{podcastId}/references` |
| GET | `/api/admin/podcasts/{podcastId}/references/{referenceId}/file` |
| GET | `/api/staff/podcasts/{podcastId}/references/{referenceId}/file` |

### AdminPodcastReviewController.java

| Method | Path |
| --- | --- |
| GET | `/api/admin/podcasts/page` |
| GET | `/api/staff/podcasts/page` |
| GET | `/api/admin/podcasts/{podcastId}` |
| GET | `/api/staff/podcasts/{podcastId}` |
| GET | `/api/admin/podcasts/{podcastId}/preview` |
| GET | `/api/staff/podcasts/{podcastId}/preview` |
| GET | `/api/admin/podcasts/{podcastId}/reviews` |
| GET | `/api/staff/podcasts/{podcastId}/reviews` |
| GET | `/api/admin/podcasts` |
| GET | `/api/staff/podcasts` |
| GET | `/api/admin/podcasts/pending-review` |
| GET | `/api/staff/podcasts/pending-review` |
| POST | `/api/admin/podcasts/{podcastId}/approve` |
| POST | `/api/staff/podcasts/{podcastId}/approve` |
| POST | `/api/admin/podcasts/{podcastId}/reject` |
| POST | `/api/staff/podcasts/{podcastId}/reject` |

### AdminUserController.java

| Method | Path |
| --- | --- |
| GET | `/api/admin/users` |
| GET | `/api/admin/users/{userId}` |
| PATCH | `/api/admin/users/{userId}` |
| PATCH | `/api/admin/users/{userId}/access` |
| PATCH | `/api/admin/users/{userId}/verification` |
| PATCH | `/api/admin/users/{userId}/role` |
| POST | `/api/admin/users/{userId}/revoke-sessions` |
| GET | `/api/admin/staff` |
| POST | `/api/admin/staff` |
| GET | `/api/admin/audit-logs` |

### AuthController.java

| Method | Path |
| --- | --- |
| POST | `/api/auth/login` |
| POST | `/api/auth/register` |
| POST | `/api/auth/refresh` |
| POST | `/api/auth/logout` |
| GET | `/api/auth/me` |

### CategoryController.java

| Method | Path |
| --- | --- |
| GET | `/api/categories` |

### CreatorAppealController.java

| Method | Path |
| --- | --- |
| GET | `/api/creator/podcasts/{podcastId}/reviews` |
| POST | `/api/creator/podcasts/{podcastId}/appeals` |
| GET | `/api/creator/podcasts/{podcastId}/appeals` |

### CreatorApplicationController.java

| Method | Path |
| --- | --- |
| POST | `/api/creator-applications` |
| GET | `/api/creator-applications/me` |

### CreatorFlowController.java

| Method | Path |
| --- | --- |
| GET | `/api/creator/series` |
| POST | `/api/creator/series` |
| GET | `/api/creator/series/{seriesId}` |
| GET | `/api/creator/series/{seriesId}/podcasts` |
| PUT | `/api/creator/series/{seriesId}` |
| DELETE | `/api/creator/series/{seriesId}` |
| GET | `/api/creator/podcasts` |
| POST | `/api/creator/podcasts` |
| GET | `/api/creator/podcasts/{podcastId}` |
| PUT | `/api/creator/podcasts/{podcastId}` |
| PUT | `/api/creator/podcasts/{podcastId}/series` |
| DELETE | `/api/creator/podcasts/{podcastId}/series` |
| POST | `/api/creator/podcasts/{podcastId}/video` |
| POST | `/api/creator/podcasts/{podcastId}/submit` |
| DELETE | `/api/creator/podcasts/{podcastId}` |

### CreatorMilestoneController.java

| Method | Path |
| --- | --- |
| POST | `/api/creator/milestones/{milestoneId}/submissions` |

### CreatorPodcastReferenceController.java

| Method | Path |
| --- | --- |
| GET | `/api/creator/podcasts/{podcastId}/references` |
| GET | `/api/creator/podcasts/{podcastId}/references/{referenceId}` |
| POST | `/api/creator/podcasts/{podcastId}/references` |
| PUT | `/api/creator/podcasts/{podcastId}/references/{referenceId}` |
| DELETE | `/api/creator/podcasts/{podcastId}/references/{referenceId}` |
| POST | `/api/creator/podcasts/{podcastId}/references/{referenceId}/file` |
| GET | `/api/creator/podcasts/{podcastId}/references/{referenceId}/file` |
| DELETE | `/api/creator/podcasts/{podcastId}/references/{referenceId}/file` |

### CreatorRequestController.java

| Method | Path |
| --- | --- |
| GET | `/api/creator/requests/incoming` |
| POST | `/api/creator/requests/{requestId}/accept` |
| POST | `/api/creator/requests/{requestId}/reject` |

### HealthController.java

| Method | Path |
| --- | --- |
| GET | `/api/health` |

### ListenerFlowController.java

| Method | Path |
| --- | --- |
| GET | `/api/podcasts` |
| GET | `/api/podcasts/{podcastId}` |
| GET | `/api/creators` |
| GET | `/api/creators/{creatorId}` |
| GET | `/api/podcasts/{podcastId}/playback` |
| PUT | `/api/podcasts/{podcastId}/listening-progress` |
| GET | `/api/me/listening-history` |
| GET | `/api/me/listening-history/{podcastId}` |
| DELETE | `/api/me/listening-history/{podcastId}` |
| GET | `/api/podcasts/{podcastId}/likes` |
| PUT | `/api/podcasts/{podcastId}/like` |
| DELETE | `/api/podcasts/{podcastId}/like` |
| GET | `/api/podcasts/{podcastId}/comments` |
| POST | `/api/podcasts/{podcastId}/comments` |
| GET | `/api/podcasts/{podcastId}/comments/stream` |
| PUT | `/api/comments/{commentId}` |
| DELETE | `/api/comments/{commentId}` |
| POST | `/api/reports` |
| GET | `/api/me/reports` |
| PATCH | `/api/me/reports/{reportId}` |
| DELETE | `/api/me/reports/{reportId}` |
| GET | `/api/me/follows` |
| PUT | `/api/creators/{creatorId}/follow` |
| DELETE | `/api/creators/{creatorId}/follow` |
| GET | `/api/me/saved-podcasts` |
| PUT | `/api/me/saved-podcasts/{podcastId}` |
| DELETE | `/api/me/saved-podcasts/{podcastId}` |
| GET | `/api/creators/{creatorId}/membership-plans` |
| GET | `/api/me/subscriptions` |
| POST | `/api/me/subscriptions` |
| DELETE | `/api/me/subscriptions/{subscriptionId}` |
| GET | `/api/me/series-requests` |
| POST | `/api/creators/{creatorId}/series-requests` |
| PUT | `/api/me/series-requests/{requestId}` |
| DELETE | `/api/me/series-requests/{requestId}` |

### ListenerMilestoneController.java

| Method | Path |
| --- | --- |
| POST | `/api/listener/milestones/{milestoneId}/approve` |
| POST | `/api/listener/milestones/{milestoneId}/revision` |

### MediaUploadController.java

| Method | Path |
| --- | --- |
| POST | `/api/uploads` |

### MilestoneDisputeController.java

| Method | Path |
| --- | --- |
| GET | `/api/milestones/{milestoneId}/submissions` |
| POST | `/api/milestones/{milestoneId}/disputes` |

### MyAdminCaseController.java

| Method | Path |
| --- | --- |
| POST | `/api/contracts/{contractId}/disputes` |
| GET | `/api/me/disputes` |
| GET | `/api/me/notifications` |
| PUT | `/api/me/notifications/{notificationId}/read` |

### PodcastReferenceController.java

| Method | Path |
| --- | --- |
| GET | `/api/podcasts/{podcastId}/references` |
| GET | `/api/podcasts/{podcastId}/references/{referenceId}/file` |

### SeriesRequestController.java

| Method | Path |
| --- | --- |
| POST | `/api/requests` |
| GET | `/api/requests/me` |
| GET | `/api/requests/{requestId}/milestones` |


