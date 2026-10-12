# Podcast History Backend

REST API for the Flutter application, built with Java 17, Maven, Spring Boot 4.1.1, Spring Data JPA, and PostgreSQL 18.

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

`POST /api/uploads` accepts authenticated `multipart/form-data` with the file field named `file` and is for images. Podcast videos must use `POST /api/creator/podcasts/{podcastId}/video`; the backend checks that the podcast belongs to the signed-in Creator, uploads under a podcast-specific object key, and stores that key and content type in the Podcast row. This prevents an uploaded video from being left unattached to a podcast. `publicUrl` is returned when `R2_PUBLIC_BASE_URL` points to the bucket's enabled R2.dev URL or custom domain, and is `null` while the bucket is private. The upload limit defaults to 100 MB and can be changed with `MEDIA_UPLOAD_MAX_FILE_SIZE`.

To use the Creator video flow in Swagger, log in with an approved Creator account and authorize with its `accessToken`. Create a draft podcast with `POST /api/creator/podcasts` using a `categoryId` and without a series. Upload its video with `POST /api/creator/podcasts/{podcastId}/video`, then submit it with `POST /api/creator/podcasts/{podcastId}/submit`. An Admin reviews the queue at `GET /api/admin/podcasts/pending-review` and approves or rejects it. The Creator can later assign an existing podcast to a series with `PUT /api/creator/podcasts/{podcastId}/series` and body `{"seriesId":"<UUID>"}`; `DELETE` on the same route removes it from the series. Images can still be uploaded through `POST /api/uploads`.

For Flutter on an Android emulator, use `http://10.0.2.2:8081` as the API base URL. For Flutter on a physical device, use the computer's LAN IP address and ensure both devices are on the same network.

## Listener flow API

All `/api` routes below require `Authorization: Bearer <accessToken>`, except health, authentication and Swagger. User-specific writes take the owner ID from the JWT.

| Feature | Routes |
|---|---|
| Explore | `GET /api/podcasts?q=&categoryId=&creatorId=&seriesId=&page=0&size=20`, `GET /api/podcasts/{podcastId}`, `GET /api/categories`, `GET /api/creators`, `GET /api/creators/{creatorId}` |
| Playback/history | `GET /api/podcasts/{podcastId}/playback`; `PUT /api/podcasts/{podcastId}/listening-progress`; `GET /api/me/listening-history`; `GET/DELETE /api/me/listening-history/{podcastId}` |
| Likes | `GET /api/podcasts/{podcastId}/likes`; `PUT/DELETE /api/podcasts/{podcastId}/like` |
| Comments | `GET/POST /api/podcasts/{podcastId}/comments`; `GET /api/podcasts/{podcastId}/comments/stream` (SSE); `PUT/DELETE /api/comments/{commentId}` |
| Reports | `POST /api/reports`; `GET /api/me/reports`; `PATCH/DELETE /api/me/reports/{reportId}`. Only `PENDING` reports can be edited or withdrawn. |
| Following | `GET /api/me/follows`; `PUT/DELETE /api/creators/{creatorId}/follow` |
| Saved podcasts | `GET /api/me/saved-podcasts`; `PUT/DELETE /api/me/saved-podcasts/{podcastId}` |
| Membership | `GET /api/creators/{creatorId}/membership-plans`; `GET/POST /api/me/subscriptions`; `DELETE /api/me/subscriptions/{subscriptionId}` |
| Creator requests | `GET /api/me/series-requests`; `POST /api/creators/{creatorId}/series-requests`; `PUT/DELETE /api/me/series-requests/{requestId}` |

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

## Content Creator podcast flow

Only a user with role `CREATOR`, an active account, and `Creator_profile.verification_status=APPROVED` can manage Creator content. Use `/api/creator/series` for series CRUD and `/api/creator/podcasts` for podcast CRUD. A podcast belongs directly to the Creator's channel and a category; `seriesId` is optional. The create/update podcast body requires `categoryId`, `title`, `slug`, `durationSeconds`, and `exclusive`, but does not require a series. A Creator may attach or detach the podcast from a series they own without changing its approval state or its category. `GET /api/creator/series/{seriesId}/podcasts` lists its assigned podcasts, and the listener catalog can filter by `seriesId`. Archiving a series detaches its podcasts, which remain on the channel. Podcast delete is a soft `DELETED` state. A podcast starts as `DRAFT`; its video is optional until upload and is stored as an R2 object key in `Podcast.media_url`. Editing an already approved podcast moves it back to draft and requires Admin approval again before it appears publicly.

For an existing database, apply [`db/migrations/2026-10-12_optional_podcast_series.sql`](db/migrations/2026-10-12_optional_podcast_series.sql) before starting this version. It copies the creator and category of every existing podcast from its current series, then makes `series_id` nullable. The old series links are preserved. For a newly created empty database, Hibernate's default `ddl-auto=update` creates the new columns.

Each video upload is explicitly linked by the route's `podcastId`: `POST /api/creator/podcasts/{podcastId}/video`. The service checks channel ownership. Uploading a replacement video for an already approved podcast moves it to `DRAFT` for review again. Submission requires a video and changes the state to `PENDING_REVIEW`. Admin endpoints are `GET /api/admin/podcasts/pending-review`, `POST /api/admin/podcasts/{podcastId}/approve`, and `POST /api/admin/podcasts/{podcastId}/reject`. Decisions are recorded in `Moderation_Review`; on approval the podcast becomes `APPROVED` and gets `published_at`.

Creators can read and post comments using the existing podcast comment APIs with their access token. The current Comment model has no parent-comment field, so threaded replies to a specific comment are not represented. The ERD's `Membership_Plan` and `Subscription` model listener support for a specific channel, so they are not reused for Creator Premium. Creator Premium billing, interaction forms, livestream, and automatic AI moderation still need their own business rules/integration; the current review queue is handled manually by Admin.
