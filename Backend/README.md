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

The backend maps 34 tables: the 32 tables in the latest ERD plus 2 supporting tables for refresh-token authentication and creator applications. Membership benefits are described in `Membership_Plan.description`. Wallet income records use `Wallet_Transaction` linked to the source `Payment`; `Payment_method` remains the payment channel recorded for that payment. Tables removed from the model are dropped by an explicit SQL migration; Hibernate `ddl-auto=update` does not drop tables or data. The application seeds the three system roles.

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

`POST /api/uploads` accepts authenticated `multipart/form-data` with the file field named `file`. It returns the bucket and `objectKey`; store the key in the podcast or profile record. `publicUrl` is returned when `R2_PUBLIC_BASE_URL` points to the bucket's enabled R2.dev URL or custom domain, and is `null` while the bucket is private. The upload limit defaults to 100 MB and can be changed with `MEDIA_UPLOAD_MAX_FILE_SIZE`.

To test from Swagger, register and log in, authorize with the returned `accessToken`, then open `POST /api/uploads`, choose a small image or video for `file`, and execute it. A successful upload returns HTTP 201 with `objectKey`, `bucket`, `publicUrl`, `contentType`, and `bytes`. Verify that the object appears in the configured Cloudflare R2 bucket.

For Flutter on an Android emulator, use `http://10.0.2.2:8081` as the API base URL. For Flutter on a physical device, use the computer's LAN IP address and ensure both devices are on the same network.

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

A logged-in Listener submits a channel application through `POST /api/creator-applications` with `channelName`, `introduction`, and optional `portfolioUrl`. They can check the latest result through `GET /api/creator-applications/me`. Applications are stored as `PENDING` and appear for admins at `GET /api/admin/creator-applications/pending`.

An Admin approves with `POST /api/admin/creator-applications/{applicationId}/approve` (optional `note`) or rejects with `POST /api/admin/creator-applications/{applicationId}/reject` (required `note`). Approval creates the Creator profile and changes the user's role to `CREATOR`; requests under `/api/creator/**` require that role. The account should refresh its JWT or log in again to receive a token containing the new role.

The seeder creates the `ADMIN` role, but does not create an admin account. To initialize one, register the account normally and run this once in PostgreSQL, replacing the email with that account's email; then log in again:

```sql
UPDATE "User"
SET role_id = (SELECT role_id FROM "Role" WHERE role_code = 'ADMIN')
WHERE email = 'admin@example.com';
```
