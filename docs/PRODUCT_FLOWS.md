# Luồng nghiệp vụ Podcast History

> Tài liệu này ghi lại các luồng nghiệp vụ do người dùng mô tả để làm căn cứ thiết kế API, database và giao diện. Mục Flow 1 ghi rõ quy tắc mục tiêu, đối chiếu API hiện có và đánh dấu các quyết định còn cần chốt; nội dung trong bảng trạng thái không hàm ý chức năng chưa triển khai đã sẵn sàng.

## Vai trò

- **Người dùng (Listener):** nghe podcast, tương tác, theo dõi creator, đăng ký hội viên kênh và gửi yêu cầu podcast.
- **Quản trị viên (Admin):** xem dashboard, quản lý người dùng, xử lý báo cáo/yêu cầu và duyệt nội dung cần can thiệp.
- **Nhà sáng tạo nội dung (CC / Content Creator):** đăng podcast, tương tác với người nghe, nhận yêu cầu làm podcast và quản lý thu nhập.

## 1. Flow người dùng (Listener)

### 1.1. Mục tiêu và điều kiện

Listener tạo tài khoản, khám phá podcast, nghe nội dung phù hợp quyền truy cập, tương tác với podcast/creator, lưu nội dung yêu thích và tùy chọn mua membership của một kênh. Các thao tác ghi dữ liệu phải gắn với người dùng lấy từ access token; client không được tự truyền `userId` để ghi thay người khác.

### 1.2. Đăng ký, đăng nhập và phiên làm việc

1. Người chưa có tài khoản gửi username, email, mật khẩu và tên hiển thị để đăng ký.
2. Hệ thống kiểm tra dữ liệu bắt buộc, định dạng email (tối đa 255 ký tự), username (3–50 ký tự), mật khẩu (8–72 ký tự), tên hiển thị (tối đa 120 ký tự) và username/email đã tồn tại chưa.
3. Nếu hợp lệ, tạo tài khoản với role `LISTENER`, lưu mật khẩu đã băm BCrypt và trả thông tin tài khoản. Đăng ký hiện không tự đăng nhập; client gọi login sau đó.
4. Đăng nhập bằng username hoặc email cùng mật khẩu. Tài khoản không hoạt động hoặc thông tin đăng nhập sai bị từ chối.
5. Khi đăng nhập thành công, client giữ access token để gọi API bảo vệ và dùng refresh token để xin cặp token mới. Đăng xuất thu hồi phiên refresh token.

**Quy tắc API hiện có:** `POST /api/auth/register` trả `201`; dữ liệu không hợp lệ trả `400`; username/email trùng trả `409`. `POST /api/auth/login` trả cặp token khi thành công và `401` nếu thông tin đăng nhập sai hoặc tài khoản bị vô hiệu hóa. Access token mặc định sống 10 phút, refresh token 7 ngày; refresh token được xoay vòng. `GET /api/auth/me` kiểm tra danh tính trong token.

**Lưu ý xác minh tài khoản:** đăng ký hiện đặt `isVerified=false`, nhưng đăng nhập chỉ kiểm tra `isActive`. Flow email/OTP xác minh chưa được mô tả và chưa được triển khai; cần chốt trước khi yêu cầu xác minh email là điều kiện đăng nhập.

### 1.3. Trang chủ, tìm kiếm và khám phá

Sau đăng nhập, Listener mở trang chủ và có thể:

- Xem danh sách podcast đã được xuất bản/được phép hiển thị.
- Tìm theo tiêu đề hoặc nội dung mô tả; lọc theo category và creator.
- Mở chi tiết podcast để xem tiêu đề, mô tả, creator, ảnh bìa, thời lượng, trạng thái và quyền nghe.
- Nhận trạng thái rỗng khi không có kết quả; không trả nội dung đang chờ duyệt, bị từ chối hoặc đã ẩn.

Phân trang, thứ tự sắp xếp và thuật toán đề xuất/trending cần được chốt khi xây dựng catalog API. Trạng thái được phép hiển thị phải dùng chung quy tắc với luồng Admin duyệt podcast.

### 1.4. Nghe podcast và lưu tiến độ

1. Client yêu cầu phát podcast.
2. Backend kiểm tra podcast tồn tại, đang được phép phát và người dùng có quyền truy cập. Nội dung độc quyền chỉ được phát khi Listener có subscription còn hiệu lực tới đúng membership plan của kênh sở hữu nội dung.
3. Client phát media URL do backend cấp/trả về; không cho phép dùng URL tùy ý để vượt quyền nội dung.
4. Trong khi nghe, client gửi tiến độ định kỳ và khi pause/thoát. Backend lưu hoặc cập nhật một bản ghi lịch sử theo cặp user–podcast, gồm giây hiện tại, trạng thái hoàn tất và thời điểm nghe gần nhất.
5. Khi mở lại podcast, client có thể tiếp tục từ tiến độ đã lưu; Listener cũng xem/xóa lịch sử theo chính sách sản phẩm.

Podcast công khai không cần membership. Podcast độc quyền cần kiểm tra subscription ở backend cho cả API lấy media URL; chỉ ẩn nút trên Flutter là không đủ để bảo vệ nội dung.

### 1.5. Thích, bình luận và báo cáo

- **Thích/bỏ thích:** một Listener chỉ có tối đa một lượt thích cho cùng podcast. Gọi lặp lại phải có kết quả ổn định; bỏ thích chỉ xóa lượt thích của chính người dùng.
- **Bình luận:** Listener xem danh sách bình luận và tạo bình luận cho podcast. Người dùng chỉ được sửa/xóa bình luận của mình; xóa mềm để giữ dấu vết quản trị. Nội dung rỗng hoặc podcast không còn hiển thị bị từ chối.
- **Bình luận thời gian thực:** sau khi lưu bình luận thành công, hệ thống phát sự kiện tới những client đang xem podcast; nếu kết nối realtime mất, client tải lại danh sách qua REST. Cần chốt WebSocket hay SSE và chính sách kiểm duyệt/xóa bình luận.
- **Báo cáo:** Listener chọn đúng một đối tượng (podcast hoặc comment; livestream nếu chức năng livestream đang bật), cung cấp mã lý do và mô tả tùy chọn. Báo cáo được lưu trạng thái chờ xử lý để Admin xem; phản hồi phải chứa mã báo cáo để theo dõi.

### 1.6. Theo dõi creator và lưu podcast

- **Follow:** Listener theo dõi/bỏ theo dõi một creator. Cặp user–creator là duy nhất và thao tác không tạo bản ghi trùng.
- **Lưu podcast yêu thích:** Listener thêm/bỏ podcast trong danh sách đã lưu của mình; danh sách chỉ hiển thị nội dung người đó đã lưu.
- ERD hiện có bảng `Follow` và `Save_postcast`. `Save_postcast` biểu diễn danh sách podcast đã lưu; ERD chưa có bảng playlist tùy chỉnh, tên playlist hoặc thứ tự podcast. Nếu “playlist” nghĩa là nhiều danh sách do Listener tự tạo, cần bổ sung mô hình playlist trước khi triển khai tính năng đó.

### 1.7. Membership của một kênh

1. Listener mở trang creator và xem các membership plan đang hoạt động của riêng kênh đó (giá, tiền tệ, thời hạn, mô tả quyền lợi).
2. Listener chọn plan và bắt đầu thanh toán.
3. Chỉ sau khi xác minh thanh toán thành công, hệ thống ghi nhận Payment thành công và tạo/kích hoạt Subscription với thời gian bắt đầu/kết thúc tương ứng.
4. Khi hết hạn, bị hủy hoặc thanh toán thất bại, subscription không cấp quyền nghe nội dung độc quyền.
5. Backend kiểm tra owner của plan và subscription của Listener; membership ở kênh A không mở nội dung độc quyền của kênh B.

Membership ở đây là gói hỗ trợ **một kênh cụ thể**, không phải gói Premium của Content Creator. Quy tắc gia hạn, hủy, hoàn tiền và cổng thanh toán cần được chốt theo nhà cung cấp thanh toán được chọn.

### 1.8. Gửi yêu cầu cho creator

Listener có membership còn hiệu lực tại kênh có thể gửi yêu cầu nội dung cho creator của kênh đó. Yêu cầu được gắn với Listener và creator, có tiêu đề, mô tả, mức phí (nếu áp dụng), tiền tệ và trạng thái. Creator phản hồi chấp nhận/từ chối; trạng thái và thời điểm phản hồi được cập nhật, Listener xem được lịch sử yêu cầu và nội dung phản hồi của mình. API Listener hiện khởi tạo `requestFee=0`; chi phí của podcast đặt làm thuộc Flow 4 và không thu ở bước gửi yêu cầu membership.

Nếu yêu cầu được xử lý như podcast đặt làm có hợp đồng, mốc bàn giao và thanh toán theo giai đoạn thì chuyển sang **Flow 4 – Podcast theo yêu cầu**; không gộp thanh toán membership với thanh toán từng mốc hợp đồng. Việc gửi yêu cầu có miễn phí hay thu phí cần được chốt.

### 1.9. Kết quả, lỗi và quyền truy cập

- Thành công: Listener xem được nội dung theo quyền, nghe và lưu tiến độ, tương tác, theo dõi, lưu podcast, hoặc sử dụng quyền lợi membership.
- `400`: dữ liệu thiếu/sai định dạng hoặc thao tác không hợp lệ.
- `401`: chưa đăng nhập, access token hết hạn/không hợp lệ; client refresh token hoặc yêu cầu đăng nhập lại.
- `403`: đã đăng nhập nhưng không sở hữu tài nguyên, không có membership phù hợp hoặc không đủ quyền.
- `404`: podcast/creator/plan không tồn tại hoặc không được phép tiết lộ.
- `409`: thao tác xung đột trạng thái, ví dụ membership/yêu cầu đã có trạng thái không cho phép gửi lại.
- API phải dùng user ID từ JWT, kiểm tra quyền sở hữu ở server và không đưa password hash/refresh token hash vào response.

### 1.10. Đối chiếu với backend hiện tại

| Phần của Flow 1 | Trạng thái hiện tại | Căn cứ / phần còn thiếu |
|---|---|---|
| Đăng ký, đăng nhập, refresh, logout, xem user hiện tại | Đã có API | `AuthController` và `AuthService`; đăng ký tạo role Listener, BCrypt; token 10 phút/7 ngày. Email verification chưa có. |
| Khám phá, tìm kiếm, chi tiết podcast/category/creator | Đã có API đọc | `GET /api/podcasts`, `/api/podcasts/{id}`, `/api/categories`, `/api/creators`; chỉ podcast đã được duyệt và creator đã duyệt. Podcast có thể không thuộc series. |
| Phát podcast và lưu tiến độ | Đã có API | `GET /api/podcasts/{id}/playback`; `PUT /api/podcasts/{id}/listening-progress`; CRUD lịch sử dưới `/api/me/listening-history`. URL R2 riêng tư có chữ ký sống 5 phút. |
| Like, comment, realtime comment, report | Đã có API | Like idempotent; comment có CRUD/xóa mềm và SSE tại `/api/podcasts/{id}/comments/stream`; report CRUD chỉ cho báo cáo của chính user, chỉ sửa/rút khi còn `PENDING`. |
| Follow creator và danh sách đã lưu | Đã có API | CRUD follow và `SavedPodcast` trên `/api/me`; chưa hỗ trợ playlist tùy chỉnh nhiều danh sách. |
| Membership và nội dung độc quyền | Có đối soát thủ công, chưa có gateway tự động | Admin quản lý plan và xác minh chuyển khoản qua `/api/admin/payments/{id}/reconcile`; PAID kích hoạt membership ACTIVE. Listener tạo checkout PENDING, xem/hủy subscription. Bucket phải private để bảo vệ media độc quyền. Xem ADMIN_STAFF_API.md. |
| Gửi yêu cầu creator từ membership | Đã có API phía Listener | CRUD yêu cầu của chính Listener dưới `/api/me/series-requests`; tạo mới cần membership `ACTIVE` cùng kênh. API creator phản hồi yêu cầu thuộc luồng CC, chưa nằm trong Flow 1. |

Các API của Flow 1 dùng JWT và lấy chủ sở hữu từ claim `user_id`; client không gửi user ID để thao tác thay người khác. Các API trả Page giới hạn tối đa 100 phần tử mỗi trang; một số API List cũ vẫn chưa phân trang. Checkout membership ghi Payment và Subscription PENDING; Listener không tự xác nhận thanh toán. Admin có thể đối soát chuyển khoản thủ công để kích hoạt ACTIVE; gateway/webhook ký số là phần tích hợp tiếp theo.

### 1.11. Các quyết định cần chốt trước khi triển khai

- Có bắt buộc xác minh email trước khi đăng nhập hay không.
- Trạng thái podcast nào được xuất hiện trong khám phá; quy tắc phân trang, sắp xếp và đề xuất.
- Giữ bucket R2 private cho media độc quyền; không được lưu URL public vào `Podcast.media_url` cho nội dung đó.
- “Playlist” chỉ là danh sách podcast đã lưu hay Listener được tạo nhiều playlist có tên.
- Quy tắc sửa/xóa, giới hạn tần suất và kiểm duyệt bình luận; realtime hiện dùng SSE.
- Cổng thanh toán, gia hạn/hủy/hoàn tiền membership và phí gửi yêu cầu cho creator.

### 1.12. Tiêu chí nghiệm thu Flow 1

1. Người dùng đăng ký được Listener; dữ liệu trùng/sai nhận lỗi phù hợp; mật khẩu trong DB chỉ là BCrypt hash.
2. Listener đăng nhập, refresh và logout theo đúng thời hạn token; API bảo vệ từ chối token không hợp lệ.
3. Tìm kiếm/trang chủ chỉ hiển thị podcast được phép xuất bản và trả được trạng thái không có kết quả.
4. Không thể nghe nội dung độc quyền nếu thiếu subscription còn hạn thuộc đúng kênh.
5. Tiến độ nghe được lưu và khôi phục đúng cho từng Listener/podcast.
6. Like, bình luận, báo cáo, follow và save luôn gắn đúng người dùng; không tạo dữ liệu trùng khi client retry.
7. Bình luận mới được truyền realtime và vẫn có thể tải lại qua REST.
8. Chỉ thanh toán thành công mới kích hoạt membership; yêu cầu creator bị từ chối nếu Listener không có quyền gửi.

## 2. Quản trị viên

1. Đăng nhập bằng tài khoản Admin.
2. Xem các dashboard.
3. Quản lý người dùng và duyệt người dùng/đơn đăng ký trở thành Content Creator.
4. Xử lý báo cáo do người dùng gửi và các yêu cầu cần Admin giải quyết.
5. Admin/Staff xem video/PDF và kiểm duyệt thủ công. AI moderation chưa triển khai theo yêu cầu hiện tại.

Các API quản trị đã bổ sung: dashboard, user/Staff, report, preview/history podcast, khiếu nại, hợp đồng/tranh chấp, membership-plan, đối soát/hoàn tiền thủ công, ví và duyệt rút tiền. Staff chỉ xử lý nội dung/report/khiếu nại và xem dashboard; Admin quản lý quyền/tài khoản/tài chính. Xem [ADMIN_STAFF_API.md](ADMIN_STAFF_API.md) để biết endpoint, body, trạng thái và các giới hạn tích hợp.

## 3. Nhà sáng tạo nội dung (CC)

1. CC đăng nhập; chỉ tài khoản có role `CREATOR`, đang hoạt động và `Creator_profile.verification_status=APPROVED` mới được quản lý nội dung.
2. CC tạo podcast ở trạng thái `DRAFT`, chọn danh mục, nhập metadata và thời lượng. Podcast thuộc trực tiếp về kênh CC; **không cần tạo hoặc chọn series** khi đăng.
3. CC upload video bằng `POST /api/creator/podcasts/{podcastId}/video`. Video được lưu trên R2 theo object key có `podcastId`, đồng thời key và MIME type được ghi vào đúng bản ghi `Podcast`. API upload media dùng chung chỉ nhận ảnh.
4. Khi video đã có, CC gửi podcast qua `POST /api/creator/podcasts/{podcastId}/submit`; trạng thái đổi thành `PENDING_REVIEW`. Admin xem hàng đợi và duyệt hoặc từ chối. Quyết định lưu trong `Moderation_Review`; duyệt chuyển sang `APPROVED`, từ chối chuyển sang `REJECTED` kèm lý do. CC có thể sửa/upload lại và gửi lại podcast bị từ chối.
5. Khi muốn gom nhóm, CC tạo series và gắn podcast hiện có vào series đó. CC có thể chuyển podcast sang series khác hoặc gỡ ra; chỉ series thuộc cùng kênh và chưa lưu trữ mới được chọn. Gắn/gỡ series không thay đổi trạng thái duyệt hoặc danh mục của podcast. Lưu trữ series tự gỡ các podcast khỏi series; các podcast vẫn thuộc kênh và tiếp tục hiển thị nếu đã duyệt. Có thể xem podcast trong series bằng `GET /api/creator/series/{seriesId}/podcasts`; Listener lọc bằng `GET /api/podcasts?seriesId=...`.
6. CC quản lý series/podcast qua API CRUD. Xóa podcast là chuyển trạng thái sang `DELETED` để không phá vỡ liên kết dữ liệu. Nếu sửa nội dung podcast đã duyệt, podcast quay về `DRAFT` và phải được Admin duyệt lại trước khi công khai. CC có thể đọc và đăng bình luận qua API comment hiện có; ERD chưa có quan hệ bình luận cha-con nên chưa hỗ trợ trả lời lồng vào một bình luận cụ thể.
7. Có thể mua **gói Premium dành cho CC** để mở các quyền lợi: đăng podcast không giới hạn, tạo biểu mẫu tương tác với người dùng và livestream.

**API Content Creator đã có:** `GET/POST /api/creator/series`, `GET/PUT/DELETE /api/creator/series/{seriesId}`, `GET /api/creator/series/{seriesId}/podcasts`, `GET/POST /api/creator/podcasts`, `GET/PUT/DELETE /api/creator/podcasts/{podcastId}`, `PUT/DELETE /api/creator/podcasts/{podcastId}/series`, `POST /api/creator/podcasts/{podcastId}/video`, `POST /api/creator/podcasts/{podcastId}/submit`. Duyệt Admin: `GET /api/admin/podcasts/pending-review`, `POST /api/admin/podcasts/{podcastId}/approve`, `POST /api/admin/podcasts/{podcastId}/reject`.

CC có thể thêm nguồn tham khảo và upload PDF gắn vào podcast qua CRUD `/api/creator/podcasts/{podcastId}/references`. Admin xem nguồn/tải PDF khi duyệt; Listener chỉ đọc nguồn của podcast đã duyệt sau khi kiểm tra quyền thành viên với nội dung độc quyền. Xem [luồng nguồn và PDF](CREATOR_UPLOAD_SOURCES.md) để gọi API theo thứ tự.

Gói Premium dành cho CC là gói của creator; gói thành viên ở mục Người dùng là gói hỗ trợ một kênh cụ thể. Đây là hai luồng gói dịch vụ khác nhau theo mô tả nghiệp vụ.

Đã có [API poll một câu hỏi, nhiều option](POLL_API.md): Creator CRUD/công bố/đóng poll và xem kết quả; Listener gửi/đổi/rút lựa chọn. Bảng Polll_questions lưu các option. Biểu mẫu nhiều câu hỏi hoặc nhiều loại đáp án chưa triển khai.

Premium Creator, giới hạn số podcast theo gói, livestream và bộ máy AI moderation chưa được triển khai: ERD/model hiện tại chưa có mô hình billing Premium Creator, và hàng đợi duyệt hiện do Admin xử lý thủ công. Poll hiện dành cho Creator đã được duyệt, chưa gắn entitlement Premium.

## 4. Podcast theo yêu cầu

1. Người dùng gửi yêu cầu podcast cho CC.
2. CC chấp nhận yêu cầu và thực hiện podcast.
3. Người dùng xem và đánh giá podcast được bàn giao.
4. Nếu người dùng phê duyệt một mốc, tiến hành thanh toán cho mốc đó.
5. Nếu podcast chưa đúng yêu cầu, người dùng có thể yêu cầu CC chỉnh sửa.
6. Kết thúc quy trình khi hoàn tất; Admin giải quyết trường hợp cần xử lý/tranh chấp.

## 5. Ví và rút tiền của CC

1. **Release Funds:** chuyển khoản thu nhập đã kiếm được sang số dư ví có thể rút.
2. CC kiểm tra số dư khả dụng.
3. Hệ thống ghi nhận giao dịch chuyển tiền vào ví.
4. CC gửi yêu cầu rút tiền.
5. Hệ thống xác thực số dư khả dụng và tài khoản thanh toán:
   - Nếu số dư hoặc tài khoản không hợp lệ, từ chối yêu cầu.
   - Nếu hợp lệ, giữ số tiền yêu cầu và bắt đầu xử lý thanh toán.
6. Ghi nhận kết quả chuyển tiền:
   - Thành công: ghi nhận giao dịch rút tiền thành công.
   - Thất bại: hoàn lại số tiền đang giữ vào số dư khả dụng và lưu kết quả thất bại.

## Ghi chú nghiệp vụ

- Chỉ giải ngân từng mốc podcast theo yêu cầu sau khi người dùng phê duyệt mốc đó.
- Khi rút tiền thất bại, số tiền đã giữ phải được hoàn lại để không làm mất số dư của CC.
- Hiện kiểm duyệt podcast thủ công qua Admin/Staff; bước AI được hoãn. Chuyển khoản/rút tiền đang được Admin đối soát thủ công, không tự gọi ngân hàng.
