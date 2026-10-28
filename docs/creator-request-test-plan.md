# Kế hoạch kiểm thử luồng Creator request của Listener

## Trạng thái phê duyệt

**Chưa triển khai.** Chờ người dùng phản hồi chính xác **“OK, làm đi”** trước khi tạo test hoặc cấu hình trong `src/test`, hay chạy `mvn test`.

## Phạm vi và giới hạn

- Kiểm tra cả luồng 6.1 (request, báo giá/milestone, bàn giao, approve/revision, tranh chấp) và 6.2 (request đơn giản).
- Không sửa production code; không kiểm tra/tích hợp SePay, QR hoặc Mục 7.
- Không đọc/chạy/sửa lại `scripts/api_regression.py` trong các bước thực thi. Script chỉ được đọc để khảo sát theo yêu cầu.
- Chỉ tạo test/config trong `Backend/src/test` và báo cáo kết quả `docs/creator-request-test-report.md`. Tài liệu kế hoạch này được tạo theo bước 3 người dùng yêu cầu.
- Không thêm dependency. Dùng `spring-boot-starter-test`/PostgreSQL driver hiện có.
- Chạy `mvn test` như người dùng yêu cầu; lệnh này bao gồm `SepayServiceTest` hiện hữu nhưng sẽ không thêm/sửa test SePay.

## Cấu hình kiểm thử đề xuất

- Test Spring Boot đầy đủ với `@SpringBootTest` + MockMvc, `@ActiveProfiles("test")`, gọi qua HTTP MVC/filter/validation và ghi/đọc JPA trên PostgreSQL thật.
- Tạo `Backend/src/test/resources/application-test.properties`; không thay đổi cấu hình production. Cấu hình kết nối qua `TEST_DB_URL`, `TEST_DB_USERNAME`, `TEST_DB_PASSWORD`, mặc định URL `jdbc:postgresql://localhost:5432/podcast_test`, username `postgres`, password rỗng nếu không đặt biến.
- Dựng schema bằng `spring.jpa.hibernate.ddl-auto=create-drop`, chỉ trong profile `test`; không chạy migration. Mỗi test dùng transaction rollback để cô lập dữ liệu.
- **Chốt an toàn DB:** kiểm tra URL hiệu lực trước khi Spring khởi tạo datasource/DDL; nếu tên DB không chứa chuỗi `test` (không phân biệt hoa thường), dừng test ngay. Không được để Hibernate kết nối hoặc chạy `create-drop` trước bước kiểm tra.
- `MEMBERSHIPS_ENABLED=false`; kiểm tra request 6.2 với Listener không có subscription.
- JWT ký bằng `JwtEncoder` của ứng dụng và khóa test giả; fixture tạo Listener, Creator đã duyệt và user khác độc lập trong DB. Không dùng token/secret thật.
- Các cấu hình Gemini, Whisper, Agora, R2 và SePay chỉ dùng giá trị giả/local trong profile test. Không gọi các dịch vụ đó; mock seam upload media trong test 6.1 để kiểm thử workflow không cần R2 thật.
- Tạo fixture role/profile qua repository/JPA. Mỗi request được gọi trong test transaction; sau test rollback để có thể chạy lặp. Không giả định dữ liệu có sẵn trong DB.

## Test files dự kiến

1. `Backend/src/test/java/com/prmteam7/podcasthistory/CreatorRequestWorkflowIntegrationTest.java` — luồng 6.1 từ tạo request đến duyệt milestone/payment `PENDING`, cùng nhánh revision và xác thực.
2. `Backend/src/test/java/com/prmteam7/podcasthistory/CreatorRequestAuthorizationAndDisputeIntegrationTest.java` — ranh giới sở hữu, status và các luồng tranh chấp milestone/hợp đồng.
3. `Backend/src/test/java/com/prmteam7/podcasthistory/SimpleCreatorRequestIntegrationTest.java` — happy path 6.2, cờ membership tắt, validation, sở hữu và trạng thái sau Creator phản hồi.
4. `Backend/src/test/resources/application-test.properties` — cấu hình riêng cho profile test, gồm URL DB an toàn và giá trị tích hợp giả.

Không tạo các file này trước khi kế hoạch được duyệt.

## Test cases và kỳ vọng

### 6.1 — request, accept và milestone

| ID | API/thao tác | Ca kiểm thử | Kỳ vọng |
|---|---|---|---|
| 61-01 | `POST /api/requests` → `GET /api/requests/me` | Listener tạo request hợp lệ; đọc lại và xác nhận `requestId`, `status=PENDING`, nội dung đã lưu | POST `201`; GET `200`; chỉ request của Listener hiện tại xuất hiện |
| 61-02 | `POST /api/requests` | `requestedTitle` rỗng/quá 220; `description` rỗng/quá 5.000; `requestFee < 0`, vượt 10 chữ số nguyên hoặc vượt 2 chữ số thập phân; `currency` không đủ/thừa 3 chữ cái | Mỗi input không hợp lệ trả `400`; không tạo request |
| 61-03 | `POST /api/requests` | Thiếu/sai token; user có role không phải Listener | Thiếu/sai token `401`; role sai theo workflow hiện tại dự kiến `409` (cần xác nhận thực tế) |
| 61-04 | `GET /api/creator/requests/incoming` → `POST /api/creator/requests/{requestId}/accept` | Creator đúng chủ sở hữu xem inbox và accept bằng response text cùng ít nhất một milestone hợp lệ | GET `200`; accept `200`; request `ACCEPTED`; response có milestone ID, amount và status |
| 61-05 | `POST /api/creator/requests/{requestId}/accept` | Response text rỗng/quá 5.000; milestone list rỗng/quá 30; tên/amount milestone sai validation | `400`; request vẫn `PENDING` |
| 61-06 | `POST /api/creator/requests/{requestId}/accept` | Creator khác accept request hoặc accept request đã được xử lý | Sai chủ sở hữu `409`; request đã xử lý `409` |
| 61-07 | `GET /api/requests/{requestId}/milestones` | Listener chủ request và Creator tham gia đọc milestone sau accept; user không tham gia thử đọc | Bên tham gia `200`, trả `milestoneId/status/amount/paymentId`; user khác `409`; request/milestone không tồn tại `404` |
| 61-08 | `POST /api/creator/milestones/{milestoneId}/submissions` → `GET /api/milestones/{milestoneId}/submissions` | Creator đúng chủ nộp multipart fixture; đọc lại lịch sử bàn giao | POST `201`; GET `200`; submission tồn tại và milestone sang `SUBMITTED`; không gọi R2 |
| 61-09 | Submission routes | Creator khác nộp hoặc Listener/user khác đọc submission; nộp ở trạng thái không cho phép | Sai chủ sở hữu/trạng thái theo workflow `409`; ID không tồn tại `404` |
| 61-10 | `POST /api/listener/milestones/{milestoneId}/approve` | Listener chủ request duyệt milestone `SUBMITTED`; đọc lại milestone/payment | POST `200`; milestone `APPROVED`; response có `paymentId`, `paymentStatus=PENDING`; milestone response có cùng `paymentId`. Không kiểm tra QR/SePay |
| 61-11 | `POST /api/listener/milestones/{milestoneId}/approve` | Duyệt milestone chưa `SUBMITTED`, đã duyệt, hoặc Listener khác duyệt | `409`; không tạo Payment thứ hai |
| 61-12 | `POST /api/listener/milestones/{milestoneId}/revision` | Lý do hợp lệ; sau đó đọc lại trạng thái | `204`; milestone `REVISION_REQUESTED` |
| 61-13 | Revision/approve | `reason` rỗng hoặc quá 5.000; revision/approve khi trạng thái không hợp lệ | Validation `400`; sai trạng thái `409` |
| 61-14 | Submission note | Note quá 5.000 ký tự | Kỳ vọng kiểm tra `400` theo yêu cầu validation; service hiện có nhánh ném `PodcastWorkflowException` cho note quá dài, nên nếu response là `409` sẽ ghi là sai lệch, không sửa production |

### 6.1 — tranh chấp và quyền sở hữu

| ID | API/thao tác | Ca kiểm thử | Kỳ vọng |
|---|---|---|---|
| 61-15 | `POST /api/milestones/{milestoneId}/disputes` | Bên tham gia mở tranh chấp khi milestone `SUBMITTED`/`REVISION_REQUESTED` | `201`; dispute được lưu; milestone `DISPUTED` |
| 61-16 | Milestone dispute | `reason` rỗng/quá 5.000; user ngoài hợp đồng mở dispute; mở dispute lần hai | Validation `400`; user khác `409`; lần hai `409`; chỉ có một dispute mở |
| 61-17 | `POST /api/contracts/{contractId}/disputes` | Listener/Creator là participant mở dispute hợp đồng | `201`; tranh chấp đọc được từ danh sách của participant |
| 61-18 | Contract dispute | `note` rỗng/quá 5.000; user ngoài hợp đồng mở dispute; mở trùng trên cùng hợp đồng | Validation `400`; user khác `403`; dispute trùng `409` |
| 61-19 | `GET /api/me/disputes?page=0&size=20` | Participant đọc danh sách sau khi tạo dispute; user khác đọc danh sách của chính họ | `200`; danh sách được phân vùng theo participant, không lộ dispute của người khác |
| 61-20 | Request/milestone/dispute protected APIs | Gửi thiếu hoặc token sai | `401`; không có dữ liệu được tạo/thay đổi |

### 6.2 — yêu cầu đơn giản

| ID | API/thao tác | Ca kiểm thử | Kỳ vọng |
|---|---|---|---|
| 62-01 | `POST /api/creators/{creatorId}/series-requests` → `GET /api/me/series-requests` | Listener không có membership gửi yêu cầu khi profile test đặt `MEMBERSHIPS_ENABLED=false`; đọc lại | POST `201`; GET `200`; request tồn tại và `PENDING` |
| 62-02 | `PUT /api/me/series-requests/{requestId}` → GET | Gửi lại cả `requestedTitle` và `description`, xác nhận cả hai cập nhật | PUT `200`; GET `200`; hai giá trị đã cập nhật |
| 62-03 | `DELETE /api/me/series-requests/{requestId}` → GET | Hủy khi còn `PENDING` | DELETE `204`; GET xác nhận `CANCELLED` |
| 62-04 | POST/PUT 6.2 | `requestedTitle` hoặc `description` rỗng/quá giới hạn 220/10.000 | `400`; không tạo/không cập nhật |
| 62-05 | PUT/DELETE 6.2 | User khác thao tác trên request của Listener | `403`; request giữ nguyên |
| 62-06 | PUT/DELETE 6.2 | Creator accept request qua endpoint accept hiện có, sau đó Listener thử sửa/hủy | Accept `200`; PUT và DELETE sau phản hồi đều `409` |
| 62-07 | POST 6.2 | Dùng token role Creator thay vì Listener | Kỳ vọng `403` cho hành trình Listener; xác minh thực tế. Đường dẫn này không nằm dưới `/api/listener/**`, còn service tạo request không có kiểm tra role Listener nhìn thấy trong khảo sát; nếu endpoint chấp nhận Creator, ghi nhận lỗi phân quyền và không sửa |
| 62-08 | GET/PUT/DELETE protected APIs | Thiếu/sai token hoặc request ID không tồn tại | Thiếu/sai token `401`; ID không tồn tại `404` |

## Đối chiếu status và các điểm cần chú ý

- Dựa trên `GlobalExceptionHandler`, validation DTO dự kiến `400`; `PodcastWorkflowNotFoundException` → `404`; `PodcastWorkflowException`/`ResourceConflictException` → `409`; `ResourceForbiddenException` → `403`.
- Luồng 6.1 kiểm tra participant ở một số service bằng `PodcastWorkflowException`, nên expected khi sai chủ sở hữu là `409`, phù hợp ghi chú audit. Contract dispute và request 6.2 dùng `ResourceForbiddenException`, nên expected `403`.
- Chưa xác nhận bằng runtime: endpoint 6.2 tạo request có kiểm tra role Listener hay không. Security matcher chỉ áp dụng role cho `/api/listener/**`/`/api/creator/**`; route POST 6.2 là `/api/creators/...`, nên cần test role âm tính.
- Note nộp sản phẩm là query parameter tùy chọn. Nếu note quá dài, code service hiện ném lỗi workflow (ánh xạ 409), trong khi tiêu chí yêu cầu kiểm tra lỗi dài trả 400; test 61-14 sẽ xác định response thật.
- Các status ở bảng là tiêu chí kiểm thử theo yêu cầu/audit; nếu runtime trả khác, test sẽ fail và báo cáo ghi rõ status thực tế cùng cách tái hiện. Không sửa production để làm test pass.

## Báo cáo sau khi được duyệt

Sau khi nhận **“OK, làm đi”**, tạo test/config trong `Backend/src/test`, chạy `mvn test`, và ghi `docs/creator-request-test-report.md` gồm lệnh/exit code, số test pass/fail, từng lỗi kèm API, status kỳ vọng/thực tế, cách tái hiện, file liên quan và severity; ghi rõ mọi phần không kiểm thử được. Không chạy script HTTP hiện có.
