# Rà soát API toàn hệ thống — 13/10/2026

> Báo cáo dưới đây là snapshot trước khi bổ sung Admin. Chức năng Admin/Staff mới, phân quyền và luồng chuyển khoản thủ công được mô tả trong [ADMIN_STAFF_API.md](ADMIN_STAFF_API.md). Số 84 operations là phiên bản đã rà soát, không phải số API sau thay đổi.

## 1. Kết luận và phạm vi kiểm tra

Backend đang chạy ở `http://localhost:8081` công bố **84 operations trong 13 controller**. Mỗi cặp HTTP method + đường dẫn được tính là một operation; không tính endpoint Swagger do framework cung cấp.

Luồng cốt lõi đăng nhập → xin quyền Creator → tạo podcast → upload video → gửi duyệt → Admin duyệt → Listener phát/tương tác đã có endpoint. Hệ thống **chưa hoàn thành toàn bộ flow sản phẩm** và **chưa thể kết luận đã tối ưu cho nhiều người dùng**.

Phạm vi thực hiện:

- Đọc toàn bộ controller; đối chiếu service, repository, model, DTO, cấu hình security/storage và `docs/PRODUCT_FLOWS.md`.
- Lấy OpenAPI thực tế từ `/v3/api-docs` của tiến trình đang chạy, đối chiếu với mappings trong mã nguồn.
- Gọi các request đọc và OPTIONS để kiểm tra public endpoint, endpoint bảo vệ và CORS; không tạo/xóa dữ liệu nghiệp vụ.
- Chưa đo tải, P95, số truy vấn thực tế hoặc chạy EXPLAIN trên PostgreSQL; các nhận xét hiệu năng là phân tích mã nguồn. Chưa xác minh cấu hình public/private của bucket Cloudflare trong tài khoản thực tế.
- Chưa thay đổi code backend. Báo cáo ghi rõ các điểm cần sửa trước khi triển khai tiếp.

## 2. API hiện có theo nhóm

| Nhóm | Số operations | Chức năng hiện có | Mức hoàn thiện |
|---|---:|---|---|
| Authentication | 5 | Register, login, me, refresh, logout | Có luồng cơ bản; thiếu quản lý tài khoản và kiểm tra active khi refresh |
| Creator applications | 2 | Gửi đơn, xem đơn của mình | Lưu trạng thái trong Creator_profile |
| Admin — creator applications | 3 | Lấy pending, approve, reject | Có xét duyệt; thiếu danh sách/history tổng quát |
| Categories | 1 | GET category active public | Có |
| Admin — categories | 5 | CRUD và tắt category | Có |
| Content Creator | 15 | CRUD series/podcast, gắn/gỡ series, video, submit | Có luồng đăng nội dung cơ bản |
| Creator — sources | 8 | CRUD nguồn, upload/get/delete PDF | Có; nguồn tùy chọn |
| Media uploads | 1 | Upload ảnh R2 | Có; chưa có quản lý/dọn media đầy đủ |
| Listener flow | 35 | Khám phá/phát/tiến độ, like/comment/SSE, report/follow/save, subscription/yêu cầu | Membership và yêu cầu sản xuất còn một phần |
| Listener — sources | 2 | Danh sách nguồn và link PDF | Có kiểm tra quyền playback |
| Admin — podcast moderation | 4 | Tất cả/pending, approve, reject | Thiếu preview video và lịch sử qua API |
| Admin — podcast sources | 2 | Danh sách nguồn và link PDF | Có |
| Health | 1 | GET health | Có endpoint; không thay thế monitoring toàn hệ thống |
| **Tổng** | **84** | | |

### Quyền truy cập hiện tại

- Public: health, login/register/refresh/logout, Swagger và `GET /api/categories`.
- `/api/creator/**`: JWT role CREATOR; service còn kiểm tra user active, profile APPROVED và quyền sở hữu.
- `/api/admin/**`: JWT role ADMIN. Một số thao tác duyệt kiểm tra role/active trong DB; category và đọc nguồn Admin chưa có kiểm tra DB tương tự.
- Listener APIs: yêu cầu JWT, kể cả khám phá và podcast PUBLIC. PUBLIC là quyền nội dung, không đồng nghĩa endpoint dành cho người chưa login.
- STAFF có matcher riêng trong security nhưng **chưa có controller `/api/staff/**`**.
- Playback/PDF MEMBERS_ONLY kiểm tra membership ACTIVE của đúng kênh, thời hạn và quyền chủ kênh.

## 3. Chức năng thiếu so với flow sản phẩm

### Listener / tài khoản

1. Quên mật khẩu, đặt lại/đổi mật khẩu, xác minh email, sửa hồ sơ/avatar của mình, quản lý phiên/thiết bị.
2. CRUD playlist đặt tên và thêm/xóa/sắp xếp podcast trong từng playlist; hiện chỉ có danh sách saved-podcasts chung.
3. Bình luận theo mốc giây trong video và reply cha/con; SSE mới thông báo comment-created, chưa có event sửa/xóa.
4. Đọc/đánh dấu đã đọc notification và gửi thông báo kết quả duyệt/yêu cầu/thanh toán.
5. API đọc danh sách/chi tiết series cho Listener nếu giao diện cần xem tiêu đề/cover trước khi lọc podcast theo seriesId. Hiện chỉ có lọc podcast bằng seriesId.

### Thành viên kênh và thanh toán

1. API CC/Admin quản lý membership-plan và quyền lợi gói.
2. Tạo giao dịch thanh toán với gateway, webhook xác minh chữ ký, chống xử lý webhook lặp và xác nhận thanh toán phía backend.
3. Chuyển subscription PENDING → ACTIVE, đặt thời gian hiệu lực từ lúc kích hoạt, xử lý hết hạn/gia hạn/thất bại.
4. Lịch sử thanh toán, trạng thái checkout chi tiết, hoàn tiền và đối soát.

`POST /api/me/subscriptions` hiện trả **202**, chỉ tạo Payment + Subscription PENDING. Không được coi là đã mua gói thành công. `startAt/endAt` đang tính ngay lúc checkout; khi làm webhook phải sửa để thời gian chờ thanh toán không làm mất ngày sử dụng.

### Content Creator

1. Sửa hồ sơ kênh/avatar/website sau khi đã APPROVED.
2. Xem lý do reject và lịch sử moderation của podcast bằng API dành cho chủ kênh. Quyết định lưu trong Moderation_Review nhưng CreatorResponses.PodcastItem chưa có note/history.
3. Quản lý Premium Creator, giới hạn số podcast và quyền lợi Premium. Đây là gói khác membership của Listener tại một kênh.
4. API nhận/chấp nhận/từ chối yêu cầu nội dung; báo giá, hợp đồng, mốc bàn giao, upload bản bàn giao, yêu cầu sửa, duyệt/đánh giá và thanh toán từng mốc.
5. CRUD poll/biểu mẫu và bỏ phiếu nếu vẫn giữ quyền lợi này trong scope.
6. Release funds, số dư ví, giao dịch, phương thức nhận tiền, yêu cầu rút tiền, giữ tiền, payout và hoàn tiền khi payout lỗi.
7. Livestream chưa có API. Nếu tính năng đã bỏ khỏi scope thì không cần triển khai lại; model còn tồn tại không đồng nghĩa endpoint đã có.

### Admin / Staff

1. Dashboard thống kê và báo cáo doanh thu/nội dung/người dùng.
2. Quản lý user: tìm/lọc, xem chi tiết, khóa/mở khóa, duyệt người dùng, quản lý vai trò và thu hồi phiên phù hợp.
3. Xử lý report: danh sách/detail, nhận xử lý, kết luận, ẩn/xóa nội dung, ghi nhận người xử lý và thông báo kết quả.
4. GET chi tiết/preview video đang chờ duyệt. Danh sách hiện chỉ có mediaKey; Admin không có API lấy signed video URL của bản chờ.
5. Lịch sử xét duyệt, gỡ nội dung đã duyệt, tiếp nhận khiếu nại và AI moderation job/result/manual fallback.
6. Xử lý tranh chấp hợp đồng, đối soát/thanh toán và duyệt rút tiền.
7. Endpoint và phân quyền nghiệp vụ riêng cho Staff nếu 5 tài khoản Staff sẽ tham gia vận hành.

## 4. API đã tối ưu chưa?

### Những điểm đã làm tốt

- Dùng DTO request/response, Bean Validation và tách controller/service/repository.
- Password BCrypt; refresh token ngẫu nhiên lưu SHA-256 hash, không lưu token gốc.
- Access token 600 giây, refresh token 604800 giây; refresh rotation, khóa PESSIMISTIC_WRITE và thu hồi token family khi phát hiện replay.
- Kiểm tra quyền sở hữu khi sửa nội dung, bình luận, report, subscription/yêu cầu.
- Có transaction và readOnly cho nhiều API đọc; open-in-view=false.
- Một số truy vấn podcast/series dùng EntityGraph hoặc fetch join để lấy quan hệ cần thiết.
- Listener có phân trang, giới hạn size tối đa 100 ở các API Page.
- Tái sử dụng S3Client/S3Presigner; upload từ file tạm, không đọc toàn bộ media thành byte array trong service.
- PDF có kiểm tra signature %PDF-, dọn file cũ sau commit và dọn file mới khi rollback. Comment realtime phát sau commit.
- Video/PDF theo podcastId; nguồn PDF là tùy chọn; URL private có thời hạn 5 phút.

### Những vấn đề cần sửa — theo thứ tự ưu tiên

#### P1 — CORS browser đang bị chặn (đã xác nhận runtime)

- Bằng chứng: OPTIONS `/api/podcasts`, Origin `http://localhost:5173`, request method GET và header authorization trả **401**; không có Access-Control-Allow-Origin/Methods.
- `SecurityConfig.java:39–66` chưa bật http.cors, không tìm thấy CorsConfigurationSource/WebMvc CORS trong dự án.
- Flutter Web hoặc frontend ở origin khác có thể bị Failed to fetch. Flutter Android/iOS native không chịu cơ chế CORS của trình duyệt. Swagger cùng origin không phải phép kiểm tra CORS cross-origin.
- Sửa: cấu hình danh sách origin frontend được phép, methods/headers và xử lý preflight trước authentication. Bucket R2 cũng cần CORS riêng nếu trình phát web truy cập R2 cross-origin; chưa xác minh cấu hình bucket.
- Tham chiếu: [Spring Security CORS](https://docs.spring.io/spring-security/reference/7.0/servlet/integrations/cors.html).

#### P1 — Refresh vẫn cấp token cho tài khoản inactive

- `AuthService.java:114–138`: kiểm tra revoked/expiry nhưng gọi issueTokenPair(current.getUser(), ...) mà không kiểm tra user.isActive. Login có kiểm tra active, refresh thì chưa.
- JWT filter chỉ dựa claim; không có kiểm tra account state/role hiện tại dùng chung. Một số API đọc, category Admin, sửa comment/report và upload ảnh chỉ dựa token hoặc không gọi requireUser.
- Hệ quả: khóa user trong DB không chặn tất cả endpoint; refresh còn có thể cấp JWT mới cho user đó.
- Sửa: khi refresh kiểm tra active và thu hồi family nếu bị khóa; thống nhất chính sách thu hồi phiên/role và kiểm tra account state cho API bảo vệ. Logout hiện thu hồi refresh family, access token vẫn có thể dùng đến hết hạn — cần ghi rõ hoặc bổ sung cơ chế thu hồi nếu nghiệp vụ yêu cầu tức thời.

#### P1 — Bucket public có thể bỏ qua bảo vệ MEMBERS_ONLY và bản nháp (điều kiện cấu hình)

- `MediaUploadService.java:128,208` tạo publicUrl cho object nếu có R2_PUBLIC_BASE_URL; ảnh/video/PDF dùng chung bucket.
- `R2PlaybackUrlService.java:49–55` tạo link public khi exclusive=false, không xét trạng thái podcast. Creator preview bản DRAFT PUBLIC có thể nhận URL public.
- Nếu bucket/domain công khai không có kiểm soát truy cập, người biết object key có thể tải video độc quyền/PDF/bản nháp trực tiếp bằng domain public. Signed URL ở API không khóa một đường truy cập public khác.
- Chưa xác nhận tài khoản R2 thực tế đang bật public; đây là lỗi thiết kế có điều kiện, không phải khẳng định đã rò rỉ dữ liệu.
- Sửa: media/video/PDF giữ private; ảnh public dùng bucket riêng, hoặc triển khai Worker/WAF authorization đúng nghiệp vụ. Không trả public URL cho media đang nháp hay độc quyền; đổi visibility phải xử lý cả quyền ở storage/cache nếu có.
- Tham chiếu: [R2 public buckets](https://developers.cloudflare.com/r2/buckets/public-buckets/), [R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/).

#### P1 — Chưa bảo vệ đồng thời cho thao tác xét duyệt/sửa podcast

- `PodcastReviewService.java:84–93`: findById → kiểm tra PENDING_REVIEW → save, không @Lock hoặc @Version.
- Model Podcast/UpdatedEntity không có @Version; các thao tác update/upload/submit cũng đọc-sửa-ghi tương tự.
- Hai request approve/reject có thể cùng đọc trạng thái chờ và ghi hai quyết định; upload và submit đồng thời có thể ghi đè trạng thái hoặc mediaKey. Transaction tự nó không bảo đảm tránh lost update ở các luồng này.
- Sửa: optimistic locking @Version hoặc khóa record/state transition có điều kiện; trả 409 khi phiên bản/trạng thái thay đổi. Khóa Creator application và refresh đã có, podcast chưa có.

#### P2 — Truy vấn danh sách có N+1

- `PodcastRepository.java:39–61`: searchPublished join quan hệ nhưng không fetch join/EntityGraph; DTO đọc category/creator/series LAZY.
- CommentRepository, ListeningHistoryRepository, SavedPodcastRepository và FollowRepository trả entity LAZY; mapper truy cập user/podcast/creator tạo thêm SELECT tùy số quan hệ chưa có trong persistence context.
- Chắc chắn có truy vấn từng phần tử tại `ListenerFlowService.java:679–697`: mỗi subscription lấy payment mới nhất; mỗi series-request lấy response mới nhất.
- Sửa: DTO projection/EntityGraph phù hợp; batch query payment/response cho cả trang; tránh fetch collection kèm phân trang. Đo query count trước/sau, không chỉ đánh giá bằng số dòng code.

#### P2 — Nhiều API chưa phân trang; search không có thứ tự ổn định

- GET Admin podcasts/pending, Creator podcasts/series/podcasts-in-series, creators, subscriptions, series-requests và application pending trả List không giới hạn.
- `ListenerFlowService.java:598–601` dùng Sort.unsorted; searchPublished không ORDER BY. Khi phân trang, kết quả có thể thay đổi thứ tự/trùng/bỏ sót giữa các lần gọi.
- Sửa: Page/Slice và size giới hạn cho danh sách tăng theo dữ liệu; search có sort publishedAt DESC + podcastId làm khóa phụ; dùng cursor nếu dataset lớn. Category ít dữ liệu có thể giữ List.

#### P2 — Search/index mới ở mức cơ bản

- Search dùng lower(... ) LIKE '%q%' và OR trên title/description/series/channel. Model Podcast hiện khai báo index FK, chưa có index phù hợp text search/status + sort. Chưa kiểm tra index ngoài model đang có trong PostgreSQL thực tế.
- Sửa sau khi đo EXPLAIN: cân nhắc pg_trgm GIN trên biểu thức lower(title/description), chiến lược tìm kiếm tiếng Việt và composite/partial index phù hợp các điều kiện thường dùng. Không thêm index cho mọi cột vì index tăng chi phí ghi.
- History/comment cũng cần xem xét index tổ hợp theo user/podcast + thời gian. Escape '%'/'_' nếu q là chuỗi tìm literal; hiện người dùng có thể dùng wildcard mở rộng kết quả.
- Tham chiếu: [PostgreSQL 18 pg_trgm](https://www.postgresql.org/docs/18/pgtrgm.html).

#### P2 — PUT dạng tìm rồi insert có thể lỗi khi nhiều request cùng lúc

- Like/follow/save/listening-progress: find/exists → create; unique constraints ngăn trùng trong DB nhưng request thứ hai có thể vi phạm constraint thay vì nhận kết quả idempotent.
- Checkout kiểm tra exists PENDING/ACTIVE rồi insert; model Subscription không có constraint/lock cho chống hai checkout đồng thời cùng user/plan.
- Sửa: upsert/khóa phù hợp, idempotency key cho checkout; xử lý DataIntegrityViolationException/constraint cụ thể thành response ổn định. Kiểm tra unique không phân biệt hoa thường cho username/email/channel/category bằng migration thay vì chỉ existsIgnoreCase ở Java.

#### P2 — Video upload còn giữ transaction trong lúc truyền R2 và chưa dọn file cũ

- `CreatorFlowService.java:201–211`: transaction bao cả network upload. Upload chậm giữ transaction/connection lâu.
- Upload lại ghi đè mediaKey nhưng không dọn object video cũ. Nếu upload thành công nhưng DB rollback, chưa có cleanup video mới tương tự PDF. Podcast DELETED cũng chưa có chính sách retention/dọn media rõ ràng.
- Ảnh upload rời không có bảng tracking/endpoint xóa: upload xong không gắn hoặc đổi thumbnail có thể để lại object không dùng.
- Sửa: tách upload khỏi transaction DB dài, finalize có version/state check, cleanup sau commit/rollback và job retry bền vững. Với video lớn cân nhắc presigned upload + finalize kiểm tra object size/type/ownership trước khi gắn; chưa có HLS/transcoding/metadata duration thực tế.

#### P2 — Xác thực ảnh/video dựa MIME client và đuôi file

- `MediaUploadService.java:171–205`: chấp nhận phần lớn image/* hoặc video/* client khai báo, không kiểm tra nội dung file ảnh/video; PDF chỉ kiểm tra 5 byte signature, chưa parse toàn tài liệu.
- durationSeconds do client nhập; không xác minh video có decode được hoặc độ dài thật. MIME tùy ý còn có thể vượt length=20 của Podcast.media_type.
- Sửa: whitelist MIME/extension, sniff/parse media đáng tin cậy, giới hạn riêng từng loại và kiểm tra codec/duration. Áp dụng quota/rate limit upload để quản lý tài nguyên.

#### P2 — SSE chỉ phù hợp demo một instance

- `CommentRealtimeHub.java:16–43`: lưu connection trong RAM, timeout=0, chưa heartbeat, hạn mức connection hoặc cơ chế shared event bus. publish gửi tuần tự ngay afterCommit.
- Restart mất stream; nhiều instance không chia sẻ sự kiện; client chậm có thể làm gửi sự kiện/response chậm. Token hết hạn/đăng xuất không tự đánh giá lại trên stream đang mở.
- Sửa: heartbeat + timeout/reconnect/catch-up qua REST, giới hạn stream/user, dispatch có backpressure; khi scale dùng event bus và chính sách kiểm tra lại quyền. Thêm event update/delete nếu frontend cần realtime đầy đủ.

#### P3 — Chuẩn hóa thời gian, trạng thái và lỗi

- PodcastReviewItem.submittedAt đang lấy podcast.updatedAt (`PodcastReviewService.java:125`), không phải mốc submit lưu riêng. Gắn/gỡ series cũng sửa updatedAt, làm sai tuổi hàng đợi duyệt.
- Nhiều status dùng String tự do; cần enum và state transition nhất quán khi hoàn thiện payment/request/wallet.
- GlobalExceptionHandler xử lý lỗi nghiệp vụ nhưng chưa chuẩn hóa DataIntegrityViolationException, sai JSON/enum/UUID/missing multipart và lỗi 401/403 từ security thành cùng ApiError. Spring vẫn có xử lý mặc định cho một số lỗi; hiện response chưa đồng nhất.
- JWT decoder chưa cấu hình validator issuer/token_type riêng; có issuer trong token phát ra. Nên xác minh các claim theo chính sách xác thực.
- Register cho phép username/email được kiểm tra riêng, nhưng login dùng OR username/email. Cần tránh username của một người trùng email của người khác và unique case-insensitive ở DB.

#### P3 — Cấu hình và vận hành chưa đủ cho môi trường triển khai

- application.properties dùng ddl-auto=update, default profile dev, database password fallback trong cấu hình và JWT key tạm nếu thiếu secret.
- Có SQL migration rời nhưng pom chưa có Flyway/Liquibase; chưa có profile production validate schema/secret bắt buộc, quản lý migration nhất quán.
- Chưa có rate limit/login throttling, job dọn refresh token hết hạn, metrics/query monitoring hoặc pipeline kiểm tra regression được cấu hình trong pom. Cần bổ sung theo môi trường triển khai và mục tiêu tải.
- TTL refresh 7 ngày hiện áp dụng lại cho token mới mỗi lần rotation: đây là thời hạn trượt. Nếu cần một phiên chỉ tồn tại tối đa 7 ngày từ login thì phải lưu session/family absolute expiry.

## 5. Frontend hiện tại

`Frontend/lib/main.dart` vẫn dùng MockAccount, đăng nhập mock và dữ liệu giao diện trong file; chưa thấy API client, bearer interceptor, refresh, multipart upload hoặc player dùng response playback thật. `Frontend/pubspec.yaml` chưa có HTTP/Dio integration tương ứng.

Vì vậy, có màn hình không đồng nghĩa chức năng đã kết nối backend. Sau khi bổ sung API và sửa P1, cần tích hợp từng luồng với baseUrl, lưu token an toàn, xử lý phân trang/401/403/409, upload progress và signed URL refresh.

## 6. Kết quả kiểm tra HTTP thực tế

| Request | Kết quả |
|---|---|
| GET /v3/api-docs | Thành công; 84 operations |
| GET /api/health | 200 |
| GET /api/categories, không token | 200 |
| GET /api/podcasts, không token | 401 |
| GET /api/admin/podcasts, không token | 401 |
| OPTIONS /api/podcasts, Origin localhost:5173, GET + authorization | 401; không có CORS allow headers |

Các request này không chứng minh CRUD, phân quyền có token, thanh toán, stream, tải R2 hoặc tốc độ khi nhiều người dùng đều hoạt động đúng. Chưa chạy benchmark hoặc thay đổi dữ liệu để kiểm chứng race conditions trong lượt rà soát này.

## 7. Thứ tự triển khai đề xuất

1. Sửa CORS, refresh/account state, media private/public và chống ghi đè đồng thời.
2. Hoàn thiện Admin preview/detail + note/history cho Creator, xử lý report và quản lý user/Staff.
3. Pagination/sort, query fetching/batching, migration/index theo kết quả EXPLAIN và xử lý idempotency.
4. Hoàn thiện membership-plan → gateway/webhook → ACTIVE/expire/refund.
5. Làm yêu cầu sản xuất/hợp đồng/mốc bàn giao → ví/giải ngân/rút tiền theo flow đã chốt.
6. Tích hợp Flutter với API thật; hoàn thiện playlist/notification/Premium/poll theo scope.
7. Đo P95, query count, connection pool, upload time, SSE connections và hành vi đồng thời trước khi đánh dấu tối ưu.

## 8. Danh mục đầy đủ endpoint đang công bố

Danh mục bên dưới trích từ OpenAPI của backend local tại thời điểm rà soát. Tên tag là tên thật trong Swagger. Phần chức năng thiếu ở trên không được tính vào 84 operations.

### Admin - categories — 5 operations

| Method | Đường dẫn | Chức năng |
|---|---|---|
| GET | `/api/admin/categories` | Danh sách tất cả category, bao gồm category đã vô hiệu hóa |
| POST | `/api/admin/categories` | Tạo category |
| DELETE | `/api/admin/categories/{categoryId}` | Vô hiệu hóa category để giữ liên kết podcast và series hiện có |
| GET | `/api/admin/categories/{categoryId}` | Xem chi tiết category |
| PUT | `/api/admin/categories/{categoryId}` | Cập nhật hoặc kích hoạt lại category |

### Admin - creator applications — 3 operations

| Method | Đường dẫn | Chức năng |
|---|---|---|
| GET | `/api/admin/creator-applications/pending` | Xem danh sách hồ sơ Creator đang chờ duyệt |
| POST | `/api/admin/creator-applications/{applicationId}/approve` | Duyệt hồ sơ Creator và chuyển vai trò User thành CREATOR |
| POST | `/api/admin/creator-applications/{applicationId}/reject` | Từ chối hồ sơ Creator đang có verification_status=PENDING |

### Admin - podcast moderation — 4 operations

| Method | Đường dẫn | Chức năng |
|---|---|---|
| GET | `/api/admin/podcasts` | Tất cả podcast hoặc lọc theo trạng thái |
| GET | `/api/admin/podcasts/pending-review` | Danh sách podcast chờ Admin duyệt |
| POST | `/api/admin/podcasts/{podcastId}/approve` | Duyệt podcast |
| POST | `/api/admin/podcasts/{podcastId}/reject` | Từ chối podcast; Creator có thể chỉnh sửa và gửi lại |

### Admin - podcast sources — 2 operations

| Method | Đường dẫn | Chức năng |
|---|---|---|
| GET | `/api/admin/podcasts/{podcastId}/references` | Admin xem nguồn để kiểm duyệt podcast |
| GET | `/api/admin/podcasts/{podcastId}/references/{referenceId}/file` | Admin lấy URL tải PDF nguồn có chữ ký |

### Authentication — 5 operations

| Method | Đường dẫn | Chức năng |
|---|---|---|
| POST | `/api/auth/login` | Đăng nhập |
| POST | `/api/auth/logout` | Đăng xuất |
| GET | `/api/auth/me` | Lấy thông tin từ JWT |
| POST | `/api/auth/refresh` | Cấp lại cặp token |
| POST | `/api/auth/register` | Tạo tài khoản Listener |

### Categories — 1 operations

| Method | Đường dẫn | Chức năng |
|---|---|---|
| GET | `/api/categories` | Danh sách category đang hoạt động, không cần đăng nhập |

### Content Creator — 15 operations

| Method | Đường dẫn | Chức năng |
|---|---|---|
| GET | `/api/creator/podcasts` | Danh sách podcast thuộc kênh Creator hiện tại |
| POST | `/api/creator/podcasts` | Tạo podcast nháp thuộc kênh Creator, chưa cần series hoặc video |
| DELETE | `/api/creator/podcasts/{podcastId}` | Đánh dấu podcast là DELETED |
| GET | `/api/creator/podcasts/{podcastId}` | Xem podcast của Creator kèm URL video |
| PUT | `/api/creator/podcasts/{podcastId}` | Cập nhật podcast; nội dung đã duyệt sẽ quay về nháp |
| DELETE | `/api/creator/podcasts/{podcastId}/series` | Gỡ podcast khỏi series; podcast vẫn thuộc kênh và giữ trạng thái duyệt |
| PUT | `/api/creator/podcasts/{podcastId}/series` | Gắn podcast hiện có vào series của kênh |
| POST | `/api/creator/podcasts/{podcastId}/submit` | Gửi podcast có video cho Admin duyệt |
| POST | `/api/creator/podcasts/{podcastId}/video` | Upload video và gắn object key vào podcast được chỉ định |
| GET | `/api/creator/series` | Danh sách series thuộc kênh Creator hiện tại |
| POST | `/api/creator/series` | Tạo series |
| DELETE | `/api/creator/series/{seriesId}` | Lưu trữ series |
| GET | `/api/creator/series/{seriesId}` | Xem một series thuộc kênh Creator hiện tại |
| PUT | `/api/creator/series/{seriesId}` | Cập nhật series |
| GET | `/api/creator/series/{seriesId}/podcasts` | Danh sách podcast đã gắn vào series của kênh |

### Content Creator - sources — 8 operations

| Method | Đường dẫn | Chức năng |
|---|---|---|
| GET | `/api/creator/podcasts/{podcastId}/references` | Danh sách nguồn của podcast thuộc Creator |
| POST | `/api/creator/podcasts/{podcastId}/references` | Thêm nguồn tham khảo, sau đó có thể upload PDF vào nguồn này |
| DELETE | `/api/creator/podcasts/{podcastId}/references/{referenceId}` | Xóa nguồn và dọn file PDF khỏi R2 |
| GET | `/api/creator/podcasts/{podcastId}/references/{referenceId}` | Xem chi tiết nguồn của podcast |
| PUT | `/api/creator/podcasts/{podcastId}/references/{referenceId}` | Cập nhật metadata nguồn; giữ file PDF hiện có |
| DELETE | `/api/creator/podcasts/{podcastId}/references/{referenceId}/file` | Gỡ file PDF, giữ metadata nguồn |
| GET | `/api/creator/podcasts/{podcastId}/references/{referenceId}/file` | Lấy URL tải PDF có chữ ký, hiệu lực 5 phút |
| POST | `/api/creator/podcasts/{podcastId}/references/{referenceId}/file` | Upload hoặc thay file PDF gắn với nguồn và podcast cụ thể |

### Creator applications — 2 operations

| Method | Đường dẫn | Chức năng |
|---|---|---|
| POST | `/api/creator-applications` | Gửi hồ sơ đăng ký Creator |
| GET | `/api/creator-applications/me` | Xem trạng thái hồ sơ Creator của tôi |

### Listener flow — 35 operations

| Method | Đường dẫn | Chức năng |
|---|---|---|
| DELETE | `/api/comments/{commentId}` |  |
| PUT | `/api/comments/{commentId}` | Cập nhật bình luận của chính Listener |
| GET | `/api/creators` | Danh sách creator đã được duyệt |
| GET | `/api/creators/{creatorId}` | Xem thông tin kênh creator |
| DELETE | `/api/creators/{creatorId}/follow` |  |
| PUT | `/api/creators/{creatorId}/follow` | Theo dõi creator |
| GET | `/api/creators/{creatorId}/membership-plans` | Xem các membership plan đang hoạt động của creator |
| POST | `/api/creators/{creatorId}/series-requests` | Gửi yêu cầu podcast tới creator có membership |
| GET | `/api/me/follows` | Danh sách creator đang theo dõi |
| GET | `/api/me/listening-history` | Xem lịch sử nghe |
| DELETE | `/api/me/listening-history/{podcastId}` |  |
| GET | `/api/me/listening-history/{podcastId}` | Xem tiến độ nghe của một podcast |
| GET | `/api/me/reports` |  |
| DELETE | `/api/me/reports/{reportId}` |  |
| PATCH | `/api/me/reports/{reportId}` |  |
| GET | `/api/me/saved-podcasts` | Danh sách podcast đã lưu |
| DELETE | `/api/me/saved-podcasts/{podcastId}` |  |
| PUT | `/api/me/saved-podcasts/{podcastId}` | Lưu podcast vào danh sách yêu thích |
| GET | `/api/me/series-requests` | Danh sách yêu cầu đã gửi cho creator |
| DELETE | `/api/me/series-requests/{requestId}` |  |
| PUT | `/api/me/series-requests/{requestId}` | Cập nhật yêu cầu khi creator chưa phản hồi |
| GET | `/api/me/subscriptions` | Xem các membership của Listener |
| POST | `/api/me/subscriptions` | Tạo checkout membership ở trạng thái chờ thanh toán |
| DELETE | `/api/me/subscriptions/{subscriptionId}` |  |
| GET | `/api/podcasts` | Tìm kiếm và khám phá podcast đã xuất bản |
| GET | `/api/podcasts/{podcastId}` | Xem chi tiết podcast |
| GET | `/api/podcasts/{podcastId}/comments` | Xem bình luận của podcast |
| POST | `/api/podcasts/{podcastId}/comments` | Tạo bình luận |
| GET | `/api/podcasts/{podcastId}/comments/stream` | Nhận bình luận mới theo thời gian thực qua Server-Sent Events |
| DELETE | `/api/podcasts/{podcastId}/like` | Bỏ thích podcast |
| PUT | `/api/podcasts/{podcastId}/like` | Thích podcast; thao tác gọi lặp là an toàn |
| GET | `/api/podcasts/{podcastId}/likes` | Xem số lượt thích và trạng thái của Listener |
| PUT | `/api/podcasts/{podcastId}/listening-progress` | Tạo hoặc cập nhật tiến độ nghe |
| GET | `/api/podcasts/{podcastId}/playback` | Kiểm tra quyền và lấy URL phát podcast |
| POST | `/api/reports` | Báo cáo podcast hoặc bình luận |

### Media uploads — 1 operations

| Method | Đường dẫn | Chức năng |
|---|---|---|
| POST | `/api/uploads` | Upload ảnh lên Cloudflare R2 |

### Podcast sources — 2 operations

| Method | Đường dẫn | Chức năng |
|---|---|---|
| GET | `/api/podcasts/{podcastId}/references` | Xem nguồn của podcast đã duyệt; nội dung độc quyền cần quyền thành viên |
| GET | `/api/podcasts/{podcastId}/references/{referenceId}/file` | Lấy URL PDF của podcast đã duyệt sau khi kiểm tra quyền truy cập |

### health-controller — 1 operations

| Method | Đường dẫn | Chức năng |
|---|---|---|
| GET | `/api/health` |  |

