# Frontend gọi API hợp đồng Listener đặt CC sản xuất audio/video

Tài liệu này dành cho luồng **hợp đồng có giữ ngân sách VND**. Các endpoint mới nằm trong Backend, nhưng chưa được kiểm thử tích hợp PostgreSQL và R2 trong môi trường này; FE nên thử ở môi trường test trước khi nhận tiền thật. [Luồng nghiệp vụ](CONTRACT_FLOW.md) và [mẫu hợp đồng](CONTRACT_TEMPLATE.md) giải thích điều khoản.

## Quy ước chung

- Gửi `Authorization: Bearer <access_token>`. JSON dùng `Content-Type: application/json`; file dùng `multipart/form-data`.
- UUID lấy từ response, không tự suy đoán. Thời gian gửi theo ISO 8601 UTC, ví dụ `2026-11-05T10:00:00Z`.
- Ngân sách và tiền từng đợt là **VND nguyên**. Phí tính theo tỷ lệ, làm tròn về VND nguyên bằng `HALF_UP`; phần CC nhận bằng tiền gộp trừ phí nên tổng luôn khớp.
- HTTP `409`: sai trạng thái, không đủ tiền, hash/phiên bản khác, vượt hạn mức hoặc đề xuất không khớp ngân sách. `404`: không tìm thấy đối tượng. `400`: body sai validation.
- Mẫu hợp đồng mới được đóng gói trong Backend tại `src/main/resources/contracts/contract-v2.md`. Hợp đồng đã tạo giữ nguyên `contentSnapshot` và `contentHash` của chính hợp đồng đó. `contentSnapshot` trả từ API là **bản phải hiển thị khi ký**; FE không dựng lại hợp đồng từ hồ sơ hiện tại.

## 1. Listener kiểm tra ví và nạp tiền nếu cần

| API | Body | Dữ liệu cần dùng |
|---|---|---|
| `GET /api/listener/wallet` | Không | `availableBalance`, `heldBalance`, `currency` |
| `POST /api/listener/wallet/top-ups` | `{"amount":100000}` | Checkout và QR SePay; chưa cộng ví ngay |
| `GET /api/me/checkouts/{checkoutId}` | Không | Chỉ tiếp tục khi checkout đã được webhook xác nhận thành công |
| `GET /api/listener/wallet/transactions?page=0&size=20` | Không | Lịch sử ví, gồm giao dịch giữ, chi đợt và hoàn ngân sách của luồng hợp đồng mới |

## 2. Listener tạo yêu cầu và giữ ngân sách

`POST /api/requests/contract` — role **LISTENER**. FE tạo `idempotencyKey` UUID một lần cho thao tác, giữ nguyên khi retry cùng nội dung. Backend khóa ví Listener, trừ số dư khả dụng và tăng số dư đang giữ **trong một transaction**. Nếu không đủ tiền, request không được tạo.
Kênh CC được chọn phải có hồ sơ `APPROVED` và tài khoản Creator đang hoạt động.

```json
{
  "idempotencyKey": "<UUID mới, giữ nguyên khi retry>",
  "creatorProfileId": "<UUID kênh CC>",
  "requestedTitle": "Podcast lịch sử Việt Nam",
  "description": "Mô tả nội dung cần sản xuất",
  "budgetAmount": 100000,
  "productType": "AUDIO",
  "fileFormat": "MP3",
  "duration": "10 phút",
  "acceptanceCriteria": "Âm thanh rõ, không rè, đúng chủ đề",
  "autoAcceptEnabled": false
}
```

`productType`: `AUDIO` hoặc `VIDEO`. `autoAcceptEnabled=true` nghĩa Listener **đồng ý trước** việc tự nghiệm thu sau 3 ngày im lặng đối với từng bản bàn giao đủ điều kiện; mặc định nên để `false` nếu FE chưa giải thích rõ. Response `201`:

```json
{"requestId":"<UUID>","status":"PENDING","budgetAmount":100000.00,"heldAmount":100000.00,"currency":"VND"}
```

FE có thể gọi `GET /api/requests/me` để xem danh sách request. Listener và CC lấy **toàn bộ nội dung request có giữ tiền** qua `GET /api/requests/{requestId}/contract-request`: `requestId`, `creatorProfileId`, `status`, `requestedTitle`, `description`, `budgetAmount`, `remainingHeld`, `currency`, `productType`, `fileFormat`, `duration`, `acceptanceCriteria`, `autoAcceptEnabled`, `createdAt`. API này dùng được cả trước khi CC đề xuất; tài khoản ngoài hai bên không xem được. Listener gọi `POST /api/requests/{requestId}/contract/cancel` để hủy **trước khi đủ hai chữ ký và hợp đồng kích hoạt**; Backend hoàn toàn bộ tiền đang giữ và đóng đề xuất nếu đã có. Sau khi hợp đồng đã kích hoạt, hai bên dùng luồng chấm dứt/tranh chấp. `DELETE /api/me/series-requests/{requestId}` của luồng cũ cũng được nối với hoàn escrow nếu request mới còn `PENDING`.

Request đã giữ tiền không sửa trực tiếp bằng `PUT /api/me/series-requests/{requestId}`. Khi cần đổi yêu cầu trước khi hợp đồng có hiệu lực, Listener hủy để nhận lại ngân sách rồi tạo request mới với `idempotencyKey` mới; điều này giữ nội dung hợp đồng và khoản tiền đã khóa nhất quán.

## 3. CC xem, từ chối hoặc tự chọn số đợt bàn giao

`GET /api/creator/requests/incoming` trả các request `PENDING` thuộc kênh CC. `GET /api/creator/requests/contracts` trả danh sách request có giữ tiền của kênh CC ở mọi trạng thái, kể cả sau khi đề xuất hoặc khi mở lại ứng dụng. Với mỗi `requestId`, CC gọi `GET /api/requests/{requestId}/contract-request` để xem ngân sách, loại file, thời lượng và tiêu chí trước khi quyết định. CC có thể gọi `POST /api/creator/requests/{requestId}/reject` với `{"responseText":"Lý do"}`; request mới bị từ chối sẽ **hoàn tiền giữ** cho Listener.

Để chấp nhận request hợp đồng mới, **CC quyết định số đợt** rồi gọi `POST /api/creator/requests/{requestId}/proposal`. Listener chỉ chọn tổng ngân sách, còn số đợt, tiền từng đợt và hạn nộp do CC đề xuất; Listener chấp nhận toàn bộ đề xuất bằng chữ ký hoặc hủy trước khi hợp đồng có hiệu lực. Ví dụ CC chọn **4 đợt** cho ngân sách 100.000 VND:

```json
{
  "responseText": "Tôi nhận sản xuất nội dung này",
  "milestones": [
    {"name":"Đợt 1","description":"Dàn ý","dueAt":"2026-11-05T10:00:00Z","amount":10000},
    {"name":"Đợt 2","description":"Bản nháp audio","dueAt":"2026-11-12T10:00:00Z","amount":20000},
    {"name":"Đợt 3","description":"Bản chỉnh sửa","dueAt":"2026-11-19T10:00:00Z","amount":30000},
    {"name":"Đợt 4","description":"Bản hoàn chỉnh","dueAt":"2026-11-26T10:00:00Z","amount":40000}
  ]
}
```

Backend yêu cầu **ít nhất một đợt**, mỗi đợt có tiền VND nguyên dương, các hạn nộp tăng dần trong tương lai và tổng `amount = budgetAmount`. Backend không đặt giới hạn 3 đợt. Bản hợp đồng tạo số hàng đúng với số đợt CC đã đề xuất; mỗi đợt được nghiệm thu và giải ngân riêng. Response là `Agreement` gồm `requestId`, `contractId`, `contractStatus: PENDING_SIGNATURE`, `contractVersion`, `contentHash`, `contentSnapshot`, `creatorSignedAt`, `listenerSignedAt`, `budgetAmount`, `remainingHeld`, `milestones[]` (có `milestoneId`, `dueAt`, `amount`, `status`). API `/accept` cũ **không chấp nhận request có escrow**, tránh bỏ qua bước ký.

## 4. Hai bên xem và ký đúng cùng một bản

1. Listener và CC gọi `GET /api/requests/{requestId}/contract`. FE hiển thị nguyên `contentSnapshot`, ngân sách, từng đợt và điều khoản. Khi chưa có đề xuất, API trả `409`.
2. Mỗi bên tự gọi `POST /api/requests/{requestId}/contract/sign` với body:

```json
{"contractVersion":2,"contentHash":"<hash từ GET contract>","accepted":true}
```

`contractVersion: 2` là ví dụ cho hợp đồng mới; FE phải lấy đúng `contractVersion` và `contentHash` từ response GET của chính hợp đồng đang ký. Backend kiểm tra người ký, phiên bản/hash, ghi `creatorSignedAt` hoặc `listenerSignedAt`. Khi đủ hai bên và tiền Listener vẫn đang giữ đủ, `contractStatus` chuyển `IN_PROGRESS`. Gọi lại cùng phiên bản/hash không tạo chữ ký thứ hai. Nếu không khớp hash, FE phải tải lại bản hợp đồng trước khi ký.

## 5. CC upload bản nháp, chờ AI duyệt, rồi mới bàn giao

Đối với hợp đồng giữ tiền, **upload không còn là bàn giao**. CC thực hiện lần lượt:

1. `POST /api/creator/milestones/{milestoneId}/drafts` với `multipart/form-data`: trường `file` (audio/video) và `note` tùy chọn. Response `201` có `draftId`, `draftNumber`, `status: PENDING`. Đợt vẫn `NOT_STARTED` hoặc `REVISION_REQUESTED`; Listener chưa thấy bản nháp và đồng hồ 3 ngày chưa chạy.
2. `GET /api/creator/milestones/{milestoneId}/drafts` để xem `status`, `aiLabel`, `aiRecommendation`, `aiConfidence`, `aiReason`, `errorMessage`. Backend chạy Whisper rồi Gemini theo lịch 30 giây. Chỉ `APPROVED` nghĩa AI đã xác nhận **lời nói an toàn** với confidence đạt ngưỡng. `PROCESSING`, `REVIEW_REQUIRED`, `REJECTED` và `FAILED` đều **không thể bàn giao**. CC có thể upload bản nháp mới; chỉ bản mới nhất được bàn giao. Với `FAILED`, bản mới sẽ được kiểm duyệt lại. `GET /api/creator/milestones/{milestoneId}/drafts/{draftId}/media` cấp URL riêng tư cho CC xem lại file.
3. Khi bản nháp mới nhất có `status: APPROVED`, CC chủ động gọi `POST /api/creator/milestones/{milestoneId}/drafts/{draftId}/deliver` (không body). Response `201` có `submissionId`, `revisionNumber`, `submittedAt`. Lúc này đợt mới chuyển `SUBMITTED`, Listener mới xem được file và thời gian 3 ngày nghiệm thu mới bắt đầu.

AI hiện **chỉ đánh giá an toàn của lời nói trong transcript**. AI không xác nhận hình ảnh video, âm nhạc, chất lượng thu âm hay mức độ đáp ứng tiêu chí hợp đồng; Listener vẫn nghiệm thu sản phẩm. Nếu Whisper không tạo được lời nói đủ rõ, Gemini không cấu hình/lỗi hoặc kết quả chưa chắc chắn, Backend chặn bàn giao theo cơ chế fail closed. API cũ `POST /api/creator/milestones/{milestoneId}/submissions` trả `409` cho hợp đồng giữ tiền để không bỏ qua bước AI; nó chỉ còn dùng cho hợp đồng cũ không giữ tiền.

| API | Ai gọi / dữ liệu | Kết quả |
|---|---|---|
| `GET /api/requests/{requestId}/milestones` | Hai bên; không body | Danh sách `milestoneId`, `dueAt`, `status`, `revisionCount`, `maxRevisions`, `paymentId` |
| `GET /api/milestones/{milestoneId}/submissions` | Hai bên; không body | Lịch sử các bản CC đã nộp |
| `GET /api/milestones/{milestoneId}/submissions/{submissionId}/media` | Hai bên hoặc Admin; không body | `url` R2 có chữ ký, `expiresAt` sau khoảng 5 phút; chỉ dùng URL này để phát file riêng tư |
| `POST /api/listener/milestones/{milestoneId}/reject` | Listener; `{"reason":"Nêu cụ thể phần phải làm lại"}` | HTTP 204; `REVISION_REQUESTED`; không chuyển tiền, CC có thể nộp lại |
| `POST /api/listener/milestones/{milestoneId}/revision` | Listener; cùng body | Cùng tác dụng và cùng hạn mức `/reject` |
| `POST /api/listener/milestones/{milestoneId}/approve` | Listener; không body | `APPROVED`, `paymentStatus: PAID`, `creatorNet`, `platformFee`, `remainingHeld` |

Listener có **3 lượt yêu cầu làm lại mỗi đợt**. Sau CC upload bản sửa, chờ AI duyệt và bấm bàn giao bản đó, đợt lại `SUBMITTED`; thời gian 3 ngày tính từ **lần bàn giao mới nhất**. Khi hết lượt, API `/reject` và `/revision` trả `409`, có thể mở tranh chấp. Nút “từ chối bản nộp” không tự chấm dứt hợp đồng.

Khi duyệt, Backend chuyển đúng tiền gộp đợt khỏi khoản đang giữ: CC nhận **80%**, app **20%** (làm tròn VND). Ví dụ đợt 20.000 VND: `creatorNet=16000`, `platformFee=4000`. Có bút toán ví của Listener và CC, phí app, `Payment PAID`; không đòi Listener thanh toán lần hai. Nếu mọi đợt được duyệt, hợp đồng thành `COMPLETED`.

Nếu `autoAcceptEnabled=true`, job Backend kiểm tra mỗi phút: chỉ tự duyệt sau **3 ngày kể từ bản nộp mới nhất**, khi đợt vẫn `SUBMITTED`, hợp đồng đang hiệu lực và chưa có phản hồi/tranh chấp. Nếu `false`, không tự duyệt. FE theo dõi bằng GET đợt/hợp đồng; job không phải API để FE gọi.

## 6. Tranh chấp và chấm dứt

**Tranh chấp một đợt:** Listener hoặc CC gọi `POST /api/milestones/{milestoneId}/disputes` với `{"reason":"..."}`. Mỗi Staff đang hoạt động nhận thông báo `DISPUTE_ASSIGNED` qua API thông báo và WebSocket. Staff và Admin xem hàng chờ qua `GET /api/admin/milestone-disputes/open`, xem bằng chứng qua `GET /api/milestones/{milestoneId}/submissions` và `GET /api/milestones/{milestoneId}/submissions/{submissionId}/media`, rồi xử lý qua `POST /api/admin/milestone-disputes/{disputeId}/resolve` với `decision: REQUEST_REVISION` hoặc `APPROVE_MILESTONE`. Nếu duyệt đợt của hợp đồng mới, Backend chỉ cho phép sau **3 ngày ưu tiên thương lượng** rồi giải ngân từ escrow theo 80/20.

**Đề nghị chấm dứt toàn hợp đồng:** Listener hoặc CC gọi `POST /api/requests/{requestId}/termination-requests` với `{"reason":"Không thể tiếp tục; nêu lý do"}`. Backend mở hồ sơ tranh chấp, gửi `DISPUTE_ASSIGNED` cho Staff, hợp đồng `DISPUTED`, đóng băng bước nghiệm thu/giải ngân. Staff và Admin xem `GET /api/admin/disputes?status=OPEN&page=0&size=20`, `GET /api/admin/disputes/{disputeId}` và `GET /api/admin/contracts/{contractId}`. Hai bên gọi `GET /api/requests/{requestId}/termination-request` để xem `status`, `createdAt`, `negotiationEndsAt`, `decision`.

Sau `negotiationEndsAt` (**3 ngày**), Staff hoặc Admin gọi `POST /api/admin/contracts/{contractId}/terminate-escrow`:

```json
{
  "reason": "Quyết định và căn cứ xử lý",
  "compensateCurrentStage": true,
  "qualifyingSubmissionId": "<UUID bản nộp của đợt hiện tại>",
  "evidenceNote": "Bản nộp đáp ứng tiêu chí tối thiểu nào"
}
```

Nếu `compensateCurrentStage=false`, bỏ `qualifyingSubmissionId` và `evidenceNote`, Backend hoàn toàn bộ tiền còn giữ. Nếu `true`, Admin phải xác định bản nộp và ghi bằng chứng đạt tiêu chí tối thiểu; Backend trả đền công gộp **30% giá trị đợt hiện tại**, phí app **10% khoản đền công**, CC nhận 90% khoản đền công, hoàn Listener phần còn giữ. Response gồm `compensationGross`, `creatorNet`, `platformFee`, `refundedToListener`, `status: TERMINATED`. Các đợt đã duyệt và thanh toán trước đó giữ nguyên. Gọi lại sau khi đã chấm dứt trả `409`, không chuyển tiền lần hai.

## 7. Luồng cũ và giới hạn kiểm thử

- `POST /api/requests` và `POST /api/creator/requests/{requestId}/accept` vẫn là luồng cũ **không giữ tiền, không ký, không giải ngân tự động**. FE của chức năng hợp đồng mới phải dùng `/api/requests/contract` và `/proposal`.
- Endpoint ký, giữ tiền, giải ngân và chấm dứt đã biên dịch và có unit test cho các bất biến chính. **Chưa có integration test PostgreSQL/R2 thành công trong môi trường này**; không coi unit test là xác nhận tiền thật đã chuyển hoặc migration đã áp dụng.
- Khi triển khai DB mà tắt Hibernate `ddl-auto=update`, áp dụng migration không phá hủy `src/main/resources/db/migrations/contract_escrow_workflow.sql` qua quy trình deployment. Không chạy migration trực tiếp vào DB dùng chung từ tài liệu này.
