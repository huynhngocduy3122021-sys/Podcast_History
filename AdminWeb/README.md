# VietCast Admin Web — Phase 2

Ứng dụng React/TypeScript/Vite độc lập cho ADMIN và STAFF. Không thay đổi Flutter Mobile hoặc Spring Boot Backend.

## Phạm vi

- Login/logout, khởi tạo phiên qua refresh + `/api/auth/me`, bảo vệ route và phân quyền.
- Sidebar, topbar, breadcrumbs; menu desktop và drawer cho màn hình nhỏ.
- Dashboard kết nối API thật, kiểm tra response bằng Zod; không có dữ liệu mẫu.
- Creator Approval (ADMIN): phân trang, lọc trạng thái, xem chi tiết, duyệt/từ chối có xác nhận và ghi chú; làm mới cache hồ sơ/Dashboard sau khi Backend xác nhận.
- Category Management (ADMIN): danh sách đầy đủ gồm inactive, tạo/sửa/kích hoạt lại, ngừng hoạt động có xác nhận. Form React Hook Form + Zod theo DTO Backend.
- 13 trang nghiệp vụ còn lại là placeholder. Không gọi API nghiệp vụ từ placeholder; dropdown thông báo dùng API cá nhân như trước.
- Loading/error/empty states, thông báo thao tác và confirmation dialog (Radix AlertDialog), chờ async, khóa gửi lặp/đóng dialog trong lúc xử lý, giữ dialog và hiển thị lỗi khi thất bại.
- Button và dialog dùng kiến trúc component cục bộ của shadcn/ui; `components.json` có sẵn. Không chạy generator tự động.

## Cài đặt và chạy

Node **22.18+** (hoặc Node 24+) để chạy test TypeScript trực tiếp. Khi chuẩn bị một checkout mới, chạy trong `AdminWeb/`:

```powershell
npm ci
Copy-Item .env.example .env
npm run dev
```

Vite dùng `http://localhost:5173`, `strictPort: true`. Backend hiện tại mặc định là `http://localhost:8081`. Khởi động Backend riêng theo hướng dẫn repository; ứng dụng này không tự khởi động, migrate hay seed Backend.

`package-lock.json` đã có. Dùng `npm ci` để cài đúng phiên bản đã khóa. Lượt sửa cấu hình ngrok không cài thêm dependencies.

## Biến môi trường

| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `VITE_API_BASE_URL` | `http://localhost:8081` | Origin Backend, không thêm `/api`, không thêm path. |

Các biến `VITE_*` công khai trong browser; tuyệt đối không đặt secret, mật khẩu hoặc token trong `.env`. Dev gọi Backend trực tiếp, không proxy. CORS local đã có trong `SecurityConfig`. Domain deploy cần được người vận hành cho phép trong `APP_CORS_ALLOWED_ORIGINS` ở Backend. Production phục vụ qua HTTPS và rewrite các route SPA về `index.html`.

Kiểm tra hiện tại thấy `AdminWeb/.env` có các biến R2, gồm `R2_ACCESS_KEY_ID` và `R2_SECRET_ACCESS_KEY`. File đã được Git ignore và các biến này không có tiền tố `VITE_`; chỉ báo tên biến, không in giá trị hoặc sửa `.env`. Nếu chứa khóa thật, nên quản lý chúng trong môi trường Backend, tránh giữ secret trong thư mục ứng dụng browser.

Khi dùng ngrok, đặt `VITE_API_BASE_URL` trong **`AdminWeb/.env`**, ví dụ `https://ten-tunnel.ngrok-free.dev` (không thêm `/api`). Sau khi sửa `.env`, dừng và chạy lại `npm run dev`; bản production cần build lại vì Vite đưa biến môi trường vào bundle. Cả Axios client xác thực và client nghiệp vụ tự thêm `ngrok-skip-browser-warning` cho domain ngrok để tránh trang cảnh báo HTML. Các biến R2 chỉ dùng cho Backend, không cấu hình địa chỉ API của AdminWeb.

Để kiểm tra Backend hiện tại, chạy `npm run check:api` khi được phép gọi môi trường đó. Script đọc URL từ `AdminWeb/.env` và tài khoản dev từ `docs/DEV_ACCOUNTS.md`, kiểm tra health, CORS, login/me/Dashboard, các API chỉ đọc nội dung, quyền sai prefix, refresh và logout. Script tạo phiên thử và thu hồi refresh token trong bước cleanup; không in token/mật khẩu hoặc dữ liệu người dùng. Không thực hiện thao tác duyệt, thanh toán hay sửa dữ liệu nghiệp vụ.

## Hợp đồng đã xác minh

Nguồn chính: [ADMIN_STAFF_API.md](../docs/ADMIN_STAFF_API.md), đối chiếu controller/DTO/service/security hiện tại trong `Backend/src/main/java/com/prmteam7/podcasthistory/`.

| Method | Endpoint thực sự được ứng dụng gọi | Hợp đồng |
|---|---|---|
| POST | `/api/auth/login` | `{identifier, password}` → `accessToken`, `refreshToken`, `tokenType`, `expiresIn`, `refreshExpiresIn`, `user` |
| POST | `/api/auth/refresh` | `{refreshToken}` → cùng DTO login, xoay vòng refresh token |
| POST | `/api/auth/logout` | `{refreshToken}` → 204, thu hồi token family |
| GET | `/api/auth/me` | Bearer → `{userId, username, email, role}` |
| GET | `/api/admin/dashboard` | ADMIN → `Dashboard` |
| GET | `/api/staff/dashboard` | STAFF → cùng `Dashboard` |
| GET | `/api/me/notifications?page=0&size=5` | Thông báo cá nhân trong dropdown, khi mở |
| GET | `/api/admin/creator-applications?status=PENDING&page=0&size=20` | `Page<CreatorApplicationResponse>`, chỉ số trang bắt đầu từ 0; bỏ status để lấy tất cả |
| GET | `/api/admin/creator-applications/{applicationId}` | Chi tiết hồ sơ |
| POST | `/api/admin/creator-applications/{applicationId}/approve` | `{note}` (không bắt buộc, tối đa 2.000 ký tự) → hồ sơ APPROVED |
| POST | `/api/admin/creator-applications/{applicationId}/reject` | `{note}` bắt buộc, không trống, tối đa 2.000 ký tự → hồ sơ REJECTED |
| GET | `/api/admin/categories` | `CategoryResponse[]`, gồm inactive; không phải Page |
| POST | `/api/admin/categories` | `{name,slug,description,active}` → 201 CategoryResponse |
| PUT | `/api/admin/categories/{categoryId}` | Cùng payload, active bắt buộc → CategoryResponse |
| DELETE | `/api/admin/categories/{categoryId}` | Xóa mềm → CategoryResponse với active=false |

`CreatorApplicationResponse`: `applicationId`, `applicantUserId`, `username`, `email`, `channelName`, `introduction`, `portfolioUrl`, `status`, `reviewNote`, `submittedAt`, `reviewedAt`. **applicationId là producerProfileId, không phải applicantUserId.** Trạng thái PENDING/APPROVED/REJECTED; chỉ PENDING có nút xét duyệt. Portfolio chỉ mở link HTTP(S), không render HTML từ Backend. Page schema giữ `content`, `number`, `size`, `totalElements`, `totalPages`; helper mới không thay đổi schema Dashboard/thông báo.

`CategoryResponse`: `categoryId`, `name`, `slug`, `description`, `active`, `createdAt`, `updatedAt`. Name không trống, tối đa 120; slug không trống, tối đa 140; description tối đa 10.000 ký tự. Backend chuẩn hóa slug thành chữ thường/gạch nối, chấp nhận chữ/số Unicode và từ chối kết quả rỗng. Tên và slug duy nhất, so sánh không phân biệt hoa/thường. Create mặc định active=true khi thiếu/null; UI luôn gửi boolean cho cả create/update. Không giả định regex slug ASCII. Giới hạn chuỗi dùng độ dài UTF-16 để khớp Jakarta `@Size`, kể cả emoji.

`ApiError`: `{timestamp,status,error,message}`. Backend validation chỉ trả thông báo của lỗi đầu tiên, không có tên trường hoặc fieldErrors. UI hiển thị lỗi 400/403/404/409, fallback cho 403 rỗng từ Spring Security; chỉ gắn lỗi trường theo thông báo đã xác minh về trùng tên, trùng slug hoặc slug không hợp lệ. Không tự suy tên trường từ thông báo validation chung; không hiển thị nội dung HTML/chẩn đoán 500. Lỗi mutation giữ form/dialog, không báo thành công; 409 cần tải lại trước khi thử tiếp.

`LoginResponse.user`: `id`, `username`, `email`, `displayName`, `role`. `displayName` được chấp nhận null. `Dashboard`: `users`, `activeUsers`, `creators`, `pendingCreators`, `podcasts`, `pendingPodcasts`, `pendingReports`, `pendingWithdrawals`, `openDisputes`, `podcastStatuses: [{status,count}]`, `collectedPayments: [{currency,amount}]`. Không dùng envelope `data` giả định; controller trả trực tiếp DTO.

`collectedPayments` là tổng PAID/SUCCESS/COMPLETED, hiển thị từng currency, không cộng chung, không gọi là lợi nhuận/số dư. Số tiền Backend dùng BigDecimal; Phase 1 chỉ hiển thị thống kê, không dùng JS number cho quyết định/giao dịch tài chính. Backend hiện trả cùng Dashboard cho Staff; UI không hiển thị các chỉ số tài chính và hàng đợi dành riêng ADMIN.

## Quyền và trạng thái phiên

- Backend là nguồn chuẩn: `SecurityConfig` yêu cầu ADMIN cho `/api/admin/**`, STAFF cho `/api/staff/**`. `AccountJwtValidator` kiểm tra user active, role hiện tại, token_version và token_type mỗi request.
- ADMIN thấy đủ 16 mục. STAFF chỉ thấy Dashboard, Podcast Moderation, Reports, Appeals và thông báo cá nhân. Gõ trực tiếp URL riêng ADMIN bị route guard chặn. 403 không refresh và được hiển thị rõ.
- Client không tự suy quyền qua JWT decode. Sau login/refresh đều gọi `/api/auth/me` trước khi công bố user.
- Access token chỉ lưu trong memory. Refresh token lưu `sessionStorage` theo tab để giữ phiên qua reload; nếu storage bị chặn thì dùng memory. Không lưu mật khẩu, không có “remember me”. Storage này có thể bị đọc bởi JavaScript cùng origin; không render HTML từ API, không ghi token vào log. Backend hiện trả token trong JSON, chưa có HttpOnly-cookie contract.
- Dùng một promise refresh cho các 401 đồng thời; 401 đến muộn của access token cũ dùng token đã xoay vòng. Request chỉ retry **một lần**; TanStack Query không tự retry. Login/refresh/logout dùng Axios riêng, không đi qua interceptor.
- Refresh thất bại hoặc retry của token hiện tại vẫn 401 sẽ xóa phiên và chuyển về login, giữ lý do an toàn để hiển thị. Retry dùng token cũ trả 401 đến muộn không xóa phiên mới đã xác minh. `revision` ngăn response đang bay khôi phục phiên sau logout hoặc đăng nhập tài khoản khác. Cache Query được xóa khi đổi identity/role hoặc logout; dashboard dùng `AbortSignal`.
- Logout xóa phiên local ngay, gửi token tới Backend để thu hồi family. Nếu mạng lỗi, thông báo rõ chưa xác nhận thu hồi server. Tab hoạt động độc lập; chưa có đồng bộ phiên đa tab. Không chia sẻ token bằng việc nhân bản tab trong lúc refresh xoay vòng.
- Initialization refresh thất bại hiển thị lỗi ở login và yêu cầu đăng nhập lại; không báo đã đăng nhập chỉ từ dữ liệu local.
- Sau login thành công, lỗi initialization cũ được xóa; logout sau đó không hiện lại lỗi cũ. Callback mutation không ghi lại cache hồ sơ nếu identity/role đã đổi trong lúc request đang chạy.

## Cấu trúc

```text
src/
  lib/             API client, schema, pagination, lỗi API, cache keys, single-flight refresh
  components/ui/   Button, confirmation dialog
  components/      Layout, notification feedback, shared states
  pages/           Login, Dashboard, Creator Approval, Categories, placeholders
  auth.tsx         Initialization, auth context, route guards
  app.tsx          Routes
  main.tsx         Providers và cache lifecycle
  styles.css       Tailwind v4 và token thương hiệu
tests/             Test Node không cần package bên ngoài
```

Màu thương hiệu lấy từ [Design System](../Frontend/docs/vietcast-design-system.md), không sao chép ràng buộc mobile vào Admin Web. Design System vẫn là nguồn chuẩn duy nhất cho thương hiệu. Không sửa hai project skill dành cho Flutter.

## Kiểm thử

```powershell
npm test
npm run typecheck
npm run lint
npm run build
npm run preview
```

`npm test` dùng `node:test` và TypeScript stripping có sẵn ở Node 22.18+/24. Kiểm tra header ngrok, refresh concurrency/failure/late 401, ma trận quyền; DTO/endpoint mappings qua Axios adapter, phân trang/List, giới hạn validation kể cả emoji, URL portfolio, lỗi API/field mapping, khóa confirmation và mutation/cache invalidation bằng QueryClient/MutationObserver thật. Không cài package mới. Chưa có kiểm thử component DOM/visual tự động; cần QA browser riêng.

Kiểm tra Phase 2 qua Backend cấu hình trong `.env`:

```powershell
npm run check:phase2
# Chỉ dùng môi trường test được phép: tạo 1 Category thử, sửa/kích hoạt lại rồi ngừng hoạt động.
npm run check:phase2 -- --category-mutations
```

Script đọc tài khoản dev từ `docs/DEV_ACCOUNTS.md`, không hardcode/in credentials hoặc tokens; logout trong cleanup. Mặc định chỉ đọc danh sách/chi tiết và kiểm tra các request không hợp lệ/ID không tồn tại (400/404), STAFF bị chặn (403). Cờ mutation kiểm tra create 201, trùng tên/slug 409, update/activate/deactivate 200, inactive vẫn có trong list. **Backend xóa mềm: một Category QA được giữ lại với active=false sau mỗi lượt có cờ này.** Không chạy trên dữ liệu production. Script không duyệt/từ chối hồ sơ Creator hiện hữu; cần hai hồ sơ PENDING thử được người vận hành cho phép để kiểm tra success và race 409.

Kết quả Phase 2: unit test **25/25** đạt; typecheck, lint, build đạt sau khi sửa các lỗi phát hiện. Build cần chạy ngoài sandbox vì esbuild bị `spawn EPERM`; vẫn có cảnh báo bundle trên 500 kB và annotation từ Zod. Backend thật xác nhận Category create/edit/reactivate/deactivate, trùng tên/slug 409; Creator list/detail/filter, invalid note 400, missing ID 404; STAFF 403. Script lúc đầu không xử lý body 403 rỗng, đã sửa và smoke check mặc định chạy lại có **0 lỗi**. Category QA đã ngừng hoạt động. Chưa xác minh Creator approve/reject success trên hồ sơ PENDING được phép thao tác, và chưa QA browser vì không có browser được kết nối.

Smoke Phase 1 `npm run check:api` cũng chạy lại với **0 lỗi**: health/CORS, login/me/Dashboard/thông báo của ADMIN và STAFF, refresh rotation, sai prefix trả 403, logout 204. Kiểm tra HTTP này xác minh Backend; không thay thế kiểm thử tương tác browser của ứng dụng.

Checklist runtime sau khi cài dependencies và chạy Backend cập nhật:

1. Đăng nhập ADMIN và STAFF bằng tài khoản thật được cấp; Listener/Creator bị từ chối.
2. Reload khởi tạo bằng refresh rồi `/me`; expired/revoked refresh quay về login.
3. STAFF nhập trực tiếp `/users`, `/payments`, `/audit-logs` → 403; menu chỉ có các quyền hỗ trợ.
4. Dashboard dùng đúng prefix role, thử Backend offline/403/response sai DTO/không có dữ liệu.
5. Nhiều GET đồng thời nhận 401 chỉ gọi một refresh; retry 401 không lặp và phản hồi cũ không xóa phiên mới. Đã có test interceptor thật với Axios adapter offline; cần xác minh thêm trên môi trường HTTP được phép.
6. Logout khi request đang chạy không tái tạo phiên; đổi tài khoản không giữ dữ liệu cache cũ.
7. Bàn phím: skip link, login labels, drawer đóng/mở, dialog focus trap/ESC, thông báo có live region.
8. Kiểm tra màn 1440/1024/768/390 px, tên user dài và zoom 150%. Chưa có visual QA screenshot.
9. ADMIN: lọc/phân trang Creator, xem đúng ID profile, ghi chú reject bắt buộc; pending khóa gửi lặp, lỗi giữ dialog. Sau success, list/detail/Dashboard tải lại; hai Admin xử lý đồng thời phải hiển thị 409 cho người đến sau.
10. Category: danh sách inactive, create/edit đúng giới hạn, duplicate map đúng trường, lỗi chung vẫn hiển thị, deactivate có confirmation và có thể activate lại. STAFF không thấy menu và bị chặn khi nhập URL hai trang này.

## Phase 2.1 và thông báo thao tác

- Giữ nguyên các câu thành công tiếng Việt đã duyệt cho Creator, tạo/sửa/ngừng hoạt động/kích hoạt lại Category và logout; các thao tác có thông báo riêng.
- Creator chỉ thành công khi nhận 200, đúng ID hồ sơ và đúng trạng thái xét duyệt. Category tạo cần 201, sửa/ngừng hoạt động cần 200; kiểm tra schema, ID khi có ID yêu cầu, tên và active cho create/update, active=false cho deactivate. Không so sánh slug đầu vào với slug trả về vì Backend chuẩn hóa slug.
- Chỉ xác nhận logout từ máy chủ sau 204; lỗi vẫn xóa phiên local nhưng không báo thu hồi server thành công.
- Phản hồi mutation sai hợp đồng/trạng thái, mất kết nối/timeout hoặc lỗi 5xx được coi là chưa xác nhận kết quả. UI không báo thành công, làm mới dữ liệu liên quan và yêu cầu kiểm tra trước khi thử lại; không tự gửi lại mutation vì các lỗi này.
- Giữ thông báo nghiệp vụ 400/403/404/409 và mapping lỗi trường đã xác minh. Login 401 dùng thông báo sai thông tin đăng nhập an toàn, không gọi đó là phiên hết hạn. Validation login dùng giới hạn UTF-16 như DTO Java; không trim mật khẩu.
- Lỗi phiên lúc chạy được giữ để trang login hiển thị; login thành công xóa lỗi cũ. Kiểm tra lại identity/role sau khi chờ invalidation trước khi hiển thị thành công.
- Kiểm tra sau cập nhật: **43/43 test đạt**, typecheck, lint và production build đạt. Tests dùng adapter offline, không tạo phiên hoặc sửa dữ liệu trên Backend thật. Chưa QA browser/HTTP cho các thay đổi Phase 2.1.
- Build còn cảnh báo annotation của Zod và bundle trên 500 kB. Test client dùng `stripTypeScriptTypes` của Node để chạy source thật trong memory và có cảnh báo experimental; không cần thêm dependency.

## Giai đoạn tiếp theo

Phase 3 đã triển khai ba route nghiệp vụ:

- `/podcast-moderation`: ADMIN/STAFF dùng prefix tương ứng để phân trang/lọc podcast, xem chi tiết/lịch sử, lấy preview video và PDF bằng signed URL tạm thời, duyệt/từ chối, ẩn/gỡ/khôi phục. `mediaKey`/`fileKey` không được dùng làm URL; Bearer token không gửi tới R2; URL ký chỉ giữ trong component memory.
- `/reports`: danh sách/chi tiết report, nhận xử lý và resolve bằng `DISMISS`, `HIDE_CONTENT`, `DELETE_CONTENT`. Livestream chỉ có DISMISS; hide/delete podcast chỉ hiện khi podcast ở APPROVED/PUBLISHED/HIDDEN; STAFF không xử lý report đã được giao cho người khác.
- `/appeals`: danh sách/chi tiết khiếu nại, ACCEPT/REJECT khi còn PENDING. ACCEPT chỉ được bật khi podcast HIDDEN/REJECTED có media và thông báo rõ rằng podcast quay về PENDING_REVIEW, không xuất bản trực tiếp.

API Phase 3 được kiểm tra bằng Zod ở response boundary. Mutation có body ghi chú tối đa 5.000 đơn vị UTF-16; approve/reject/claim/resolve yêu cầu response 200 đúng ID/trạng thái; hide/restore/delete yêu cầu 204 và không parse body. Conflict 409, lỗi quyền, lỗi media/R2, response malformed hoặc mất kết nối không báo thành công; dữ liệu liên quan được tải lại khi có thể.

Tests offline hiện tại: **47/47 đạt**, typecheck, lint và production build đạt. Build còn cảnh báo annotation từ Zod và bundle khoảng 635 kB. Chưa chạy login/CRUD thật trên Backend hoặc QA browser; signed URL, R2 expiry và race 409 cần xác minh thêm trên môi trường test được phép. Không triển khai payment gateway, AI moderation, tự chuyển khoản hoặc các luồng Backend chưa hỗ trợ.
