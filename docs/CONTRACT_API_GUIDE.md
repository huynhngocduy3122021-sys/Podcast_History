# Frontend gọi API hợp đồng Listener đặt CC sản xuất audio/video

Tài liệu này dành cho luồng **hợp đồng có giữ ngân sách VND**. Các endpoint mới nằm trong Backend, nhưng chưa được kiểm thử tích hợp PostgreSQL và R2 trong môi trường này; FE nên thử ở môi trường test trước khi nhận tiền thật. [Luồng nghiệp vụ](CONTRACT_FLOW.md) và [mẫu hợp đồng](CONTRACT_TEMPLATE.md) giải thích điều khoản.

## Quy ước chung

- Gửi `Authorization: Bearer <access_token>`. JSON dùng `Content-Type: application/json`; file dùng `multipart/form-data`.
- UUID lấy từ response, không tự suy đoán. Thời gian gửi theo ISO 8601 UTC, ví dụ `2026-11-05T10:00:00Z`.
- Ngân sách và tiền từng đợt là **VND nguyên**. Phí tính theo tỷ lệ, làm tròn về VND nguyên bằng `HALF_UP`; phần CC nhận bằng tiền gộp trừ phí nên tổng luôn khớp.
- HTTP `409`: sai trạng thái, không đủ tiền, hash/phiên bản khác, vượt hạn mức hoặc đề xuất không khớp ngân sách. `404`: không tìm thấy đối tượng. `400`: body sai validation.
- Mẫu hợp đồng mới được đóng gói trong Backend tại `Backend/src/main/resources/contracts/contract-v4.md`. Hợp đồng đã tạo giữ nguyên `contentSnapshot` và `contentHash` của chính hợp đồng đó. `contentSnapshot` trả từ API là **bản phải hiển thị khi ký**; FE không dựng lại hợp đồng từ hồ sơ hiện tại.

## 1. Listener kiểm tra ví và nạp tiền nếu cần

| API | Body | Dữ liệu cần dùng |
|---|---|---|
| `GET /api/listener/wallet` | Không | `availableBalance`, `heldBalance`, `currency` |
| `POST /api/listener/wallet/top-ups` | `{"amount":100000}` | Checkout và QR SePay; chưa cộng ví ngay |
| `GET /api/me/checkouts/{checkoutId}` | Không | Chỉ tiếp tục khi checkout đã được webhook xác nhận thành công |
| `GET /api/listener/wallet/transactions?page=0&size=20` | Không | Lịch sử ví, gồm giao dịch giữ, chi đợt và hoàn ngân sách của luồng hợp đồng mới |

## 2. Listener tạo yêu cầu, chưa giữ ngân sách

`POST /api/requests/contract` — role **LISTENER**. FE tạo `idempotencyKey` UUID một lần cho thao tác, giữ nguyên khi retry cùng nội dung. Backend chỉ lưu yêu cầu và ngân sách dự kiến, **chưa trừ ví/chưa giữ tiền**. Listener cần có đủ tiền khi CC gửi đề xuất; có thể nạp trước hoặc sau lúc tạo request.
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
{"requestId":"<UUID>","status":"PENDING","budgetAmount":100000.00,"heldAmount":0.00,"currency":"VND"}
```

FE có thể gọi `GET /api/requests/me` để xem danh sách request. Listener và CC lấy **toàn bộ nội dung yêu cầu hợp đồng** qua `GET /api/requests/{requestId}/contract-request`: `requestId`, `creatorProfileId`, `status`, `requestedTitle`, `description`, `budgetAmount`, `remainingHeld`, `fundsHeld`, `currency`, `productType`, `fileFormat`, `duration`, `acceptanceCriteria`, `autoAcceptEnabled`, `createdAt`. Trước khi CC gửi đề xuất, `fundsHeld=false`, `remainingHeld=0`. API này dùng được cả trước khi CC đề xuất; tài khoản ngoài hai bên không xem được. Listener gọi `POST /api/requests/{requestId}/contract/cancel` để hủy **trước khi đủ hai chữ ký và hợp đồng kích hoạt**; trước đề xuất không có tiền để hoàn, sau đề xuất Backend hoàn toàn bộ tiền đang giữ và đóng đề xuất. Sau khi hợp đồng đã kích hoạt, hai bên dùng luồng chấm dứt/tranh chấp. `DELETE /api/me/series-requests/{requestId}` của luồng cũ cũng được nối với hủy request hợp đồng nếu request còn `PENDING`.

Request hợp đồng không sửa trực tiếp bằng `PUT /api/me/series-requests/{requestId}`. Khi cần đổi yêu cầu trước khi hợp đồng có hiệu lực, Listener hủy rồi tạo request mới với `idempotencyKey` mới; nếu tiền đã được giữ thì Backend hoàn lại trước.

## 3. CC xem, từ chối hoặc tự chọn số đợt bàn giao

`GET /api/creator/requests?page=0&size=20` là danh sách thống nhất của kênh CC, gồm request cũ và request có giữ tiền ở **mọi trạng thái**. Có thể thêm `status=PENDING|ACCEPTED|REJECTED|CANCELLED`; bỏ `status` để xem tất cả. `page` bắt đầu từ 0, `size` mặc định 20 và tối đa 100. Response là `Page` với `content[]`, `totalElements`, `totalPages`; mỗi phần tử có `requestId`, `listenerId`, `creatorProfileId`, `title`, `description`, `proposedBudget`, `currency`, `status`, `createdAt`, `respondedAt`, `flowType` (`LEGACY` hoặc `ESCROW`) và, nếu là escrow, `productType`, `contractId`, `contractStatus`. Request `ESCROW` chưa được CC đề xuất có `contractId`/`contractStatus` là `null`. Chỉ dữ liệu gửi đến kênh của CC đang đăng nhập được trả về.

`GET /api/creator/requests/incoming` vẫn trả các request `PENDING` thuộc kênh CC. `GET /api/creator/requests/contracts` trả riêng các request thuộc luồng hợp đồng ở mọi trạng thái, kể cả khi tiền chưa được giữ. Với `flowType=ESCROW`, CC gọi `GET /api/requests/{requestId}/contract-request` để xem ngân sách, loại file, thời lượng và tiêu chí trước khi quyết định. CC có thể gọi `POST /api/creator/requests/{requestId}/reject` với `{"responseText":"Lý do"}`; từ chối trước đề xuất không cần hoàn tiền vì chưa giữ ngân sách.

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

Backend yêu cầu **ít nhất một đợt**, mỗi đợt có tiền VND nguyên dương, các hạn nộp tăng dần trong tương lai và tổng `amount = budgetAmount`. Backend không đặt giới hạn 3 đợt. Khi đề xuất hợp lệ, Backend khóa ví Listener, chuyển toàn bộ ngân sách từ số dư khả dụng sang số dư giữ, ghi giao dịch `CONTRACT_HOLD` và tạo hợp đồng **trong cùng transaction**. Nếu ví không đủ tiền, API trả `409`, request vẫn `PENDING` và CC có thể gửi lại đề xuất sau khi Listener nạp tiền. Bản hợp đồng tạo số hàng đúng với số đợt CC đã đề xuất; mỗi đợt được nghiệm thu và giải ngân riêng. Response là `Agreement` gồm `requestId`, `contractId`, `contractStatus: PENDING_SIGNATURE`, `contractVersion`, `contentHash`, `contentSnapshot`, `creatorSignedAt`, `listenerSignedAt`, `budgetAmount`, `remainingHeld`, `milestones[]` (có `milestoneId`, `dueAt`, `amount`, `status`). API `/accept` cũ **không chấp nhận request có escrow**, tránh bỏ qua bước ký.

## 4. Hai bên xem và ký đúng cùng một bản

1. Listener và CC gọi `GET /api/requests/{requestId}/contract`. FE hiển thị nguyên `contentSnapshot`, ngân sách, từng đợt và điều khoản. Khi chưa có đề xuất, API trả `409`.
2. Mỗi bên tự gọi `POST /api/requests/{requestId}/contract/sign` với body:

```json
{"contractVersion":3,"contentHash":"<hash từ GET contract>","accepted":true}
```

`contractVersion: 3` là ví dụ cho hợp đồng mới; FE phải lấy đúng `contractVersion` và `contentHash` từ response GET của chính hợp đồng đang ký. Backend kiểm tra người ký, phiên bản/hash, ghi `creatorSignedAt` hoặc `listenerSignedAt`. Khi đủ hai bên và tiền Listener vẫn đang giữ đủ, `contractStatus` chuyển `IN_PROGRESS`. Gọi lại cùng phiên bản/hash không tạo chữ ký thứ hai. Nếu không khớp hash, FE phải tải lại bản hợp đồng trước khi ký.

### Chat riêng trong hợp đồng

Sau khi CC gửi đề xuất và hợp đồng được tạo, **chỉ Listener và CC của hợp đồng** được gọi:

- `GET /api/requests/{requestId}/chat/messages?page=0&size=20`: lấy lịch sử tin nhắn, mới nhất trước; `size` tối đa 100. Hai bên vẫn đọc được lịch sử sau khi hợp đồng đóng.
- `POST /api/requests/{requestId}/chat/messages`: gửi tin khi hợp đồng `PENDING_SIGNATURE`, `IN_PROGRESS` hoặc `DISPUTED`. Body ví dụ: `{"clientMessageId":"<UUID tạo một lần cho tin này>","content":"Đợt 1 dự kiến hoàn thành khi nào?"}`. Gửi lại cùng `clientMessageId` và nội dung sẽ nhận cùng `messageId` mà không tạo tin trùng. Nội dung là văn bản 1–2000 ký tự; API trả `201` với `messageId`, `requestId`, `contractId`, `senderId`, `clientMessageId`, `content`, `createdAt`.

Để nhận tin mới theo thời gian thực, FE kết nối STOMP `/ws` với header CONNECT `Authorization: Bearer <token>`, rồi SUBSCRIBE `/user/queue/contract-chat`. Event sau khi transaction lưu tin thành công có `type: CONTRACT_CHAT_MESSAGE` và `data` là tin nhắn vừa lưu. Event chỉ gửi vào user queue của hai bên; FE dùng `requestId` trong `data` để đưa tin vào đúng cuộc trò chuyện. Khi kết nối lại, gọi GET lịch sử để lấy tin đã bỏ lỡ. **Không gửi tin qua STOMP**; dùng POST để Backend kiểm tra người tham gia và lưu lịch sử. Chat dùng để trao đổi tiến độ/yêu cầu thêm, không tự sửa nội dung hợp đồng, ngân sách hay các đợt đã ký.

## 5. CC upload bản nháp, chờ AI duyệt, rồi mới bàn giao

Đối với hợp đồng giữ tiền, **upload không còn là bàn giao**. CC thực hiện lần lượt:

1. `POST /api/creator/milestones/{milestoneId}/drafts` với `multipart/form-data`: trường `file` (audio/video) và `note` tùy chọn. Response `201` có `draftId`, `draftNumber`, `status: PENDING`. Đợt vẫn `NOT_STARTED` hoặc `REVISION_REQUESTED`; Listener chưa thấy bản nháp và đồng hồ 3 ngày chưa chạy.
2. `GET /api/creator/milestones/{milestoneId}/drafts` để xem `status`, `aiLabel`, `aiRecommendation`, `aiConfidence`, `aiReason`, `errorMessage`. Backend chạy Whisper rồi Gemini theo lịch 30 giây. Chỉ `APPROVED` nghĩa AI đã xác nhận **lời nói an toàn** với confidence đạt ngưỡng. `PROCESSING`, `REVIEW_REQUIRED`, `REJECTED` và `FAILED` đều **không thể bàn giao**. CC có thể upload bản nháp mới; chỉ bản mới nhất chưa hủy/chưa bàn giao được bàn giao. Nếu muốn dùng lại bản trước đã `APPROVED`, CC gọi `POST /api/creator/milestones/{milestoneId}/drafts/{draftId}/cancel` cho **bản mới nhất** (không body). Response `200` trả bản nháp với `status: CANCELLED`; bản trước trở thành bản mới nhất có thể bàn giao mà không phải upload hoặc AI duyệt lại. Có thể hủy cả khi bản nháp đang `PROCESSING`; kết quả worker đến sau sẽ không khôi phục bản đã hủy. API không xóa file và không hủy bản đã bàn giao. `GET /api/creator/milestones/{milestoneId}/drafts/{draftId}/media` cấp URL riêng tư cho CC xem lại file.
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

CC gọi `GET /api/creator/wallet/transactions?page=0&size=20` với token Creator để xem lịch sử ví của mình. Có thể thêm `status=COMPLETED`; bỏ `status` để xem mọi trạng thái. Response là `Page` với `content[]`, `totalElements`, `totalPages`; mỗi giao dịch có `transactionId`, `type`, `direction`, `amount`, `currency`, `status`, `referenceCode`, `balanceAfter`, `heldBalanceAfter`, `createdAt`. Khoản CC nhận từ đợt được duyệt có `type=RELEASE_FUNDS`, `direction=CREDIT`, `referenceCode=CONTRACT_CREATOR:<milestoneId>`. `GET /api/creator/wallet/balance` cho số dư hiện tại. Listener tiếp tục xem khoản giữ, trừ và hoàn qua `GET /api/listener/wallet/transactions`.

Nếu `autoAcceptEnabled=true`, job Backend kiểm tra mỗi phút: chỉ tự duyệt sau **3 ngày kể từ bản nộp mới nhất**, khi đợt vẫn `SUBMITTED`, hợp đồng đang hiệu lực và chưa có phản hồi/tranh chấp. Nếu `false`, không tự duyệt. FE theo dõi bằng GET đợt/hợp đồng; job không phải API để FE gọi.

## 6. Tranh chấp và chấm dứt

**Tranh chấp một đợt:** Listener hoặc CC gọi `POST /api/milestones/{milestoneId}/disputes` với `{"reason":"Sản phẩm không đạt tiêu chí","listenerWinAction":"REFUND_STAGE_CONTINUE"}`. Nếu Listener mở, `listenerWinAction` bắt buộc và là `REFUND_STAGE_CONTINUE` hoặc `CANCEL_CONTRACT`. Nếu CC mở, bỏ trường này; Listener chọn khi xác nhận. Đợt chuyển `DISPUTED`, tranh chấp `AWAITING_RESPONSE`; bên còn lại nhận thông báo `DISPUTE_CONFIRM_REQUIRED` qua API thông báo/WebSocket. FE hiển thị `responseDeadlineAt` và cho bên còn lại gọi `POST /api/milestones/{milestoneId}/disputes/{disputeId}/confirm` với body `{}` (CC) hoặc `{"listenerWinAction":"REFUND_STAGE_CONTINUE"}` (Listener). Người mở không tự xác nhận được.

**Tranh chấp toàn hợp đồng:** Listener hoặc CC gọi `POST /api/requests/{requestId}/termination-requests` với body như trên (`reason`, và `listenerWinAction` nếu Listener mở). Cũng có thể gọi `POST /api/contracts/{contractId}/disputes` với `{"note":"Lý do","listenerWinAction":"CANCEL_CONTRACT"}`. Hợp đồng chuyển `DISPUTED`; bên còn lại nhận `DISPUTE_CONFIRM_REQUIRED`. Bên còn lại gọi `POST /api/disputes/{disputeId}/confirm` với body `{}` (CC) hoặc `{"listenerWinAction":"CANCEL_CONTRACT"}` (Listener). Hai bên xem `GET /api/requests/{requestId}/termination-request` hoặc `GET /api/me/disputes`. Phản hồi có `status`, `opponentConfirmedAt`, `listenerWinAction`, `decision`; hạn xác nhận là `negotiationEndsAt` trong API request hoặc `responseDeadlineAt` trong API tranh chấp.

**Hết hạn / Staff:** Nếu bên còn lại không xác nhận trong 3 ngày, job Backend tự kết luận người mở thắng. Nếu xác nhận đúng hạn, tranh chấp chuyển `OPEN`, Staff nhận `DISPUTE_ASSIGNED`. Staff và Admin xem `GET /api/admin/milestone-disputes?status=OPEN` (hoặc `status=AWAITING_RESPONSE`) và `GET /api/admin/disputes?status=OPEN&page=0&size=20` (hoặc `status=AWAITING_RESPONSE`); xem chứng cứ qua `GET /api/milestones/{milestoneId}/submissions` và `/media`. Staff/Admin quyết định bằng `POST /api/admin/milestone-disputes/{disputeId}/resolve` hoặc `POST /api/admin/disputes/{disputeId}/resolve`, body `{"decision":"LISTENER_WINS","note":"Căn cứ xử lý"}` hoặc `CREATOR_WINS`. Listener thắng: `CANCEL_CONTRACT` hoàn toàn bộ tiền escrow còn giữ và chấm dứt; `REFUND_STAGE_CONTINUE` hoàn riêng đợt hiện tại, đánh dấu `SKIPPED_REFUNDED`, tiếp tục hợp đồng. Các đợt đã thanh toán không bị thu hồi. CC thắng: khôi phục trạng thái trước tranh chấp; đợt chưa tự nghiệm thu/giải ngân. Nếu đã bật tự nghiệm thu, đồng hồ 3 ngày bắt đầu lại từ khi kết luận CC thắng. Cả hai bên nhận `DISPUTE_RESULT`. Các lệnh xác nhận, quyết định, hoàn tiền sau khi đã xử lý sẽ bị từ chối để tránh lặp.

**Luồng chấm dứt cũ:** Với tranh chấp cũ đã mở trước khi áp dụng xác nhận hai bên (`opponentConfirmedAt` trống), sau `negotiationEndsAt`, Staff/Admin có thể gọi `POST /api/admin/contracts/{contractId}/terminate-escrow`:

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
- Khi triển khai DB mà tắt Hibernate `ddl-auto=update`, áp dụng migration không phá hủy trong `Backend/src/main/resources/db/migrations/`, gồm `contract_escrow_workflow.sql`, `contract_chat.sql` và `dispute_confirmation.sql`, qua quy trình deployment. Không chạy migration trực tiếp vào DB dùng chung từ tài liệu này.
