# Podcast History Backend

REST API for the Flutter application, built with Java 17, Maven, Spring Boot 4.1.1, Spring Data JPA, and PostgreSQL 18.

## Admin and Staff operations

See [Admin/Staff API guide](../docs/ADMIN_STAFF_API.md) for dashboard, user access,
reports, moderation preview/history, appeals, contract disputes, membership plans,
manual payment reconciliation/refunds and withdrawal review. Staff handles content;
Admin handles users, roles and finance. Podcast moderation uses Whisper transcripts and Gemini; a `SAFE` + `APPROVE` result automatically approves the podcast, while other outcomes stay in the Admin review queue.

The additive schema migration is `db/migrations/2026-10-13_admin_operations.sql`.
With the current `ddl-auto=update`, restarting applies entity schema additions.
Builds do not update a running backend process. Local CORS is enabled; configure
`APP_CORS_ALLOWED_ORIGINS` for a deployed frontend. Locking users or changing their
roles revokes old sessions using `User.token_version`.

## Package layout

Application code is organized by responsibility under `com.prmteam7.podcasthistory`:

- `controller`: REST controllers, including authentication and health endpoints.
- `dto.request` and `dto.response`: request and response objects used by controllers.
- `service`: business logic called by controllers.
- `repository`: Spring Data repositories used by services.
- `model`: JPA entities and shared persistence models.
- `exception`: application exceptions and the global REST exception handler.
- `enums`: Java enums; this package uses the plural name because `enum` is a Java keyword.
- `config`: Spring and application configuration.

The request flow is `controller -> DTO -> service -> repository -> model`.

## Create the database

The connection defaults to the exact-case database name `Podcast_History` on `localhost:5432`. Create it once from this directory with the setup script. It asks for the PostgreSQL role and password locally; the password is not written to the project:

```powershell
.\create_database.ps1
```

## Run locally

Set the PostgreSQL credentials in the current PowerShell session, then run from this `Backend` directory:

```powershell
$env:DB_USERNAME = 'postgres'
$env:DB_PASSWORD = '<your PostgreSQL password>'
mvn spring-boot:run
```

The backend maps the latest ERD plus a supporting refresh-token table. Creator applications use `Creator_profile.verification_status`; there is no separate creator-application table. Membership benefits are described in `Membership_Plan.description`. Wallet income records use `Wallet_Transaction` linked to the source `Payment`; `Payment_method` remains the payment channel recorded for that payment. Tables removed from the model are dropped by an explicit SQL migration; Hibernate `ddl-auto=update` does not drop tables or data. The application seeds system roles and, in the default local `dev` profile, the shared development accounts described in [`docs/DEV_ACCOUNTS.md`](../docs/DEV_ACCOUNTS.md).

## Gói CC đăng ký với hệ thống

Gói hệ thống dành cho Creator tách biệt với `/api/admin/membership-plans` (gói listener theo từng kênh). Gói hệ thống dùng chung cho tất cả CC và không có `creatorId` trong request tạo gói. Admin quản lý tại `/api/admin/creator-system-plans`: `GET` danh sách, `GET /{planId}`, `POST`, `PUT /{planId}`, `DELETE /{planId}`. DELETE ngừng bán gói (`INACTIVE`) để giữ lịch sử đăng ký; gói Free mặc định không thể xóa. PUT có thể kích hoạt lại gói.

Lần đầu chạy, hệ thống tạo Free (0đ, tối đa 3 podcast có video/audio) và Plus (50.000 VND/30 ngày, đăng không giới hạn, có quyền livestream). Admin tự quản lý danh sách `benefits` của từng gói; giá trị mặc định chỉ là dữ liệu khởi tạo. Ví dụ request tạo/sửa Plus:

```json
{
  "code": "PLUS",
  "name": "Plus",
  "description": "Gói CC trả phí",
  "price": 50000,
  "currency": "VND",
  "durationDays": 30,
  "status": "ACTIVE",
  "benefits": [
    { "key": "UPLOAD_LIMIT", "value": "unlimited", "description": "Đăng podcast không giới hạn" },
    { "key": "LIVESTREAM", "value": "true", "description": "Quyền livestream khi tính năng ra mắt" },
    { "key": "PRIORITY_SUPPORT", "value": "true", "description": "Ưu tiên hỗ trợ" }
  ]
}
```

`UPLOAD_LIMIT` nhận số nguyên không âm hoặc `unlimited`; thiếu key này nghĩa là không được upload. `LIVESTREAM` nhận `true` hoặc `false`. Hai quyền này được API hiểu; các key khác được lưu và trả về cho client, cần triển khai chức năng tương ứng mới có hiệu lực. Livestream hiện chỉ là quyền trong gói, chưa có API phát trực tiếp. Giá trị quyền lợi của lượt Plus đã mua được giữ đến khi gói hết hạn; sửa gói chỉ ảnh hưởng lượt mua sau. Sửa Free có hiệu lực ngay.

Danh mục key/value đang hỗ trợ và cách backend áp dụng: [`docs/CREATOR_SYSTEM_PLAN_BENEFIT_KEYS.md`](../docs/CREATOR_SYSTEM_PLAN_BENEFIT_KEYS.md).

CC dùng `GET /api/creator/system-plans` để xem gói, `GET /api/creator/system-plans/me` để xem quyền và lượt đăng còn lại, `POST /api/creator/system-plans/{planId}/subscribe` để giả lập thanh toán thành công và kích hoạt gói trả phí. Gói Free là mặc định, không cần đăng ký. Mỗi CC chỉ có một lượt đăng ký trả phí còn hiệu lực; sau khi hết hạn có thể mua tiếp. Upload video/audio lần đầu cho một podcast được tính là một lượt; thay file của podcast đó không tính thêm. Số lượt đã đăng không đặt lại khi Plus hết hạn. Thanh toán chỉ là mô phỏng, không thu tiền thật.

Với `ddl-auto=update`, Hibernate tạo bảng mới khi khởi động. Nếu dùng `ddl-auto=validate`, áp dụng `db/migrations/2026-10-19_creator_system_plans.sql` trước khi chạy API.

The server listens on `http://localhost:8081`. Check that it is running at:

```text
GET http://localhost:8081/api/health
```

It returns:

```json
{"status":"UP","service":"podcast-history-backend"}
```

## Cloudflare R2 image and video uploads

Create an R2 bucket and an R2 API token with Object Read & Write permission for that bucket. Fill `R2_ENDPOINT`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, and `R2_BUCKET_NAME` in `Backend/.env`. The endpoint format is `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`; R2 uses region `auto`. Spring Boot loads `.env` when started from either the repository root or the `Backend` directory. `Backend/.env` is ignored by Git; `.env.example` lists the variables. Restart the backend after changing the file.

Create a draft podcast first, then upload its cover through `POST /api/creator/podcasts/{podcastId}/thumbnail` with authenticated `multipart/form-data` and the file field named `file`. The response is the updated podcast with `thumbnailUrl`. Set `R2_PUBLIC_BASE_URL` to the bucket's enabled R2.dev URL or custom domain so clients can display the uploaded cover. The upload limit defaults to 100 MB and can be changed with `MEDIA_UPLOAD_MAX_FILE_SIZE`.

To use the Creator video flow in Swagger, log in with an approved Creator account and authorize with its `accessToken`. Create a draft podcast with `POST /api/creator/podcasts` using a `categoryId` and without a series. Upload its cover with `POST /api/creator/podcasts/{podcastId}/thumbnail` and its video or audio with `POST /api/creator/podcasts/{podcastId}/video`, then submit it with `POST /api/creator/podcasts/{podcastId}/submit`. Gemini automatically approves podcasts when its completed result is `SAFE` with recommendation `APPROVE`; an Admin reviews remaining cases at `GET /api/admin/podcasts/pending-review`. The Creator can later assign an existing podcast to a series with `PUT /api/creator/podcasts/{podcastId}/series` and body `{"seriesId":"<UUID>"}`; `DELETE` on the same route removes it from the series.

For Flutter on an Android emulator, use `http://10.0.2.2:8081` as the API base URL. For Flutter on a physical device, use the computer's LAN IP address and ensure both devices are on the same network.

## Listener flow API

All `/api` routes below require `Authorization: Bearer <accessToken>`, except health, authentication and Swagger. User-specific writes take the owner ID from the JWT.

| Feature | Routes |
|---|---|
| Explore | `GET /api/podcasts?q=&categoryId=&creatorId=&seriesId=&page=0&size=20`, `GET /api/podcasts/{podcastId}`, `GET /api/categories`, `GET /api/creators?q=channelName`, `GET /api/creators/{creatorId}` |
| Playback/history | `GET /api/podcasts/{podcastId}/playback`; `PUT /api/podcasts/{podcastId}/listening-progress`; `GET /api/me/listening-history`; `GET/DELETE /api/me/listening-history/{podcastId}` |
| Likes | `GET /api/podcasts/{podcastId}/likes`; `PUT/DELETE /api/podcasts/{podcastId}/like` |
| Comments | `GET/POST /api/podcasts/{podcastId}/comments`; `GET /api/podcasts/{podcastId}/comments/stream` (SSE); `PUT/DELETE /api/comments/{commentId}` |
| Reports | `POST /api/reports`; `GET /api/me/reports`; `PATCH/DELETE /api/me/reports/{reportId}`. Only `PENDING` reports can be edited or withdrawn. |
| Following | `GET /api/me/follows`; `PUT/DELETE /api/creators/{creatorId}/follow` |
| Saved podcasts | `GET /api/me/saved-podcasts`; `PUT/DELETE /api/me/saved-podcasts/{podcastId}` |
| Membership | `GET /api/creators/{creatorId}/membership-plans`; `GET/POST /api/me/subscriptions`; `DELETE /api/me/subscriptions/{subscriptionId}` |
| Creator requests | `GET /api/me/series-requests`; `POST /api/creators/{creatorId}/series-requests`; `PUT/DELETE /api/me/series-requests/{requestId}` |

Search channels with `GET /api/creators?q=history`. The optional `q` matches part of `channelName` without case sensitivity and returns approved Creator channels sorted by name. Omitting `q` keeps the full list response. Each item includes `creatorProfileId`, `channelName`, `description`, `avatarUrl`, and `websiteUrl`; use `creatorProfileId` with `GET /api/podcasts?creatorId=<UUID>` to list that channel's published podcasts.

Membership checkout currently creates a `PENDING` subscription and payment record. It does not grant access or mark payment successful; connect a payment provider and verify its signed callback before enabling membership. Listener series requests start with a zero request fee; any paid custom-production contract belongs to Flow 4. The `is_exclusive` column defaults to `false` and is added by Hibernate `ddl-auto=update` or `db/migrations/2026-10-12_add_podcast_exclusive.sql`. For exclusive media, store the R2 object key in `Podcast.media_url` and keep the R2 bucket private; playback responses use a five-minute signed URL.

## Authentication API and Swagger

`POST /api/auth/register` creates a Listener account. The password is encoded with BCrypt before it is saved; the raw password is never returned by the API.

`POST /api/auth/login` accepts either a username or an email and checks the stored BCrypt password hash:

```http
POST /api/auth/login
Content-Type: application/json
```

```json
{
  "identifier": "listener@example.com",
  "password": "your-password"
}
```

Successful login returns `accessToken` (10 minutes) and `refreshToken` (7 days), plus the public user profile. Send `accessToken` in the `Authorization: Bearer <token>` header to call `GET /api/auth/me`. `POST /api/auth/refresh` accepts the current refresh token, revokes it, and returns a new token pair. Reusing a rotated token revokes the remaining token in that session. `POST /api/auth/logout` revokes the refresh-token session. Invalid credentials or refresh tokens receive HTTP 401.

Set `JWT_SECRET` in `.env` to a private random string with at least 32 UTF-8 bytes. If it is omitted, the app creates a temporary key for local development, so tokens stop working after a restart.

Open Swagger UI at `http://localhost:8081/swagger-ui.html`; the OpenAPI document is at `http://localhost:8081/v3/api-docs`. In Swagger, call `POST /api/auth/register`, then `POST /api/auth/login`; copy `accessToken`, choose **Authorize**, enter the access token, and call `GET /api/auth/me`. Use `refreshToken` only with the refresh and logout endpoints.

The database stores refresh-token hashes, not raw refresh tokens, and checks that `"User".password_hash` contains a BCrypt hash. Apply `db/migrations/2026-10-11_auth_refresh_tokens.sql` to an existing database before starting with `spring.jpa.hibernate.ddl-auto=validate`; the default `update` setting also creates the refresh-token table.

`JWT_SECRET` should be set to a stable random value of at least 32 UTF-8 bytes when running the backend. When it is absent, the backend generates a temporary key for local development, so access JWTs stop working after a restart; refresh tokens remain stored and can issue a new pair. `JWT_ACCESS_TOKEN_TTL_SECONDS` defaults to 600 and `JWT_REFRESH_TOKEN_TTL_SECONDS` defaults to 604800.

## Creator channel approval

A logged-in Listener submits a channel application through `POST /api/creator-applications` with `channelName`, `introduction`, and optional `portfolioUrl`. The request is stored on `Creator_profile` with `verification_status=PENDING`; the user remains a Listener while waiting. They can check the status through `GET /api/creator-applications/me`. Pending profiles appear for admins at `GET /api/admin/creator-applications/pending`.

An Admin approves with `POST /api/admin/creator-applications/{applicationId}/approve` (optional `note`) or rejects with `POST /api/admin/creator-applications/{applicationId}/reject` (required `note`). Approval changes `Creator_profile.verification_status` to `APPROVED` and the user's role to `CREATOR`; requests under `/api/creator/**` require that role. The account should refresh its JWT or log in again to receive a token containing the new role.

Development credentials and the startup seeding behavior are documented in [`docs/DEV_ACCOUNTS.md`](../docs/DEV_ACCOUNTS.md). The seeded staff accounts use the distinct `STAFF` role and cannot access `/api/admin/**`.

```sql
UPDATE "User"
SET role_id = (SELECT role_id FROM "Role" WHERE role_code = 'ADMIN')
WHERE email = 'admin@example.com';
```

## Listener podcast requests and milestones

Apply `db/migrations/2026-10-13_podcast_request_milestones.sql` to an existing database before deploying this workflow. It adds milestone amounts, upload/revision/dispute history, and a unique payment-per-milestone constraint. New installations using Hibernate `ddl-auto=update` create the mapped tables automatically.

All amounts are decimal values with up to two fractional digits; currency defaults to `USD` and is stored as a three-letter code.

- `POST /api/requests` — Listener submits `creatorProfileId`, `requestedTitle`, `description`, and optional `requestFee`/`currency`.
- `GET /api/requests/me` — Listener lists submitted requests.
- `GET /api/creator/requests/incoming` — Creator lists pending incoming requests.
- `POST /api/creator/requests/{requestId}/accept` — Creator accepts and defines `responseText` and a non-empty `milestones` array (`name`, optional `description`, `amount`).
- `POST /api/creator/requests/{requestId}/reject` — Creator rejects with `responseText`.
- `GET /api/requests/{requestId}/milestones` — Request participants retrieve milestones and related payment IDs.
- `POST /api/creator/milestones/{milestoneId}/submissions` — Creator submits a file and optional note as multipart form data. Audio files such as MP3, M4A, WAV, OGG, Opus, and FLAC are supported by the shared upload service.
- `GET /api/milestones/{milestoneId}/submissions` — Participants (and Admin) view submission history.
- `POST /api/listener/milestones/{milestoneId}/approve` — The Listener who created the request approves the submitted milestone.
- `POST /api/listener/milestones/{milestoneId}/revision` — That Listener requests a revision with a `reason`.
- `POST /api/milestones/{milestoneId}/disputes` — Either contract participant opens a dispute with a `reason`.
- `GET /api/admin/milestone-disputes/open` and `POST /api/admin/milestone-disputes/{disputeId}/resolve` — Admin lists and resolves milestone disputes. Resolution decision is `APPROVE_MILESTONE` or `REQUEST_REVISION`, with a required `note`. Contract-level disputes keep `/api/admin/disputes` and their separate `RESUME_CONTRACT`, `CANCEL_CONTRACT`, `COMPLETE_CONTRACT` decisions.

Approval creates one `Payment` with status `PENDING` and returns its ID. This project does not yet integrate a payment provider; `PENDING` is not proof of payment, and a provider callback/confirmation endpoint must be integrated before treating the milestone as paid. Business-rule violations return HTTP 409; missing workflow records return HTTP 404.

## Creator wallet and payouts

Apply `db/migrations/2026-10-13_z_creator_wallet_payout.sql` to an existing database after `db/migrations/2026-10-13_podcast_request_milestones.sql` and before deploying wallet and payout endpoints. The migration adds the held balance, payout-account reference fields, the verified payout-account table, ledger idempotency constraints, and non-negative wallet checks.

All endpoints require a JWT. `/api/creator/**` requires the `CREATOR` role and `/api/admin/**` requires the `ADMIN` role. Wallets are created with `USD` currency on first access; this workflow does not perform currency conversion.

- `POST /api/creator/wallet/release-funds` — Idempotently transfers wallet earnings for `PAID` payments whose milestone is `APPROVED`. A pending payment from milestone approval is not eligible; a payment provider must first confirm it as paid. Response includes the number and total amount released and the updated balance.
- `GET /api/creator/wallet/balance` — Returns available, held, and total balance.
- `GET /api/creator/wallet/payout-accounts` — Lists active payout accounts (masked destination only).
- `POST /api/creator/wallet/withdrawals` — Body: `{"amount": 25.00, "payoutAccountId": "<verified account UUID>"}`. A valid request atomically moves funds from available to held and records a pending withdrawal.
- `GET /api/creator/wallet/withdrawals` — Returns the Creator's withdrawal history and status.
- `POST /api/admin/payouts/creators/{creatorProfileId}/accounts` — Registers an account after an operator verifies it with a payout provider. Body: `{"payoutMethod":"BANK","accountReference":"<provider token>","accountMasked":"****1234","currency":"USD"}`. The reference must be an opaque provider token, never a raw bank/card number.
- `GET /api/admin/payouts/withdrawals/pending` — Lists pending payout requests and their provider account reference for authorized Admin processing. Keep this reference confidential.
- `POST /api/admin/payouts/withdrawals/{withdrawalId}/result` — Body: `{"result":"SUCCESS","providerReference":"<provider transaction ID>","note":"optional"}` or `{"result":"FAILED","note":"optional"}`. `SUCCESS` completes the held debit; `FAILED` restores the funds to available. Terminal requests cannot be processed twice.

No payout provider is currently integrated: an authorized Admin/operator executes the transfer outside the application and records the outcome. The result endpoint is not an automated provider callback. Database transactions protect wallet/ledger changes and do not remain open while an external transfer is in progress.
