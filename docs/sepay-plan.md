# SePay QR Payment Integration Plan

## Scope

Replace the existing membership checkout's pending-only response with a SePay
bank-transfer QR flow. The backend creates a unique payment code, returns a QR
image URL, accepts SePay webhook notifications, updates the linked Payment and
Subscription atomically, and exposes an owner-checked status endpoint for
frontend polling.

No refunds, frontend changes, or deletion of unrelated payment functionality
are included.

## Confirmed choices

- QR image base URL: `https://vietqr.app/img`, configurable through `sepay.qr-base-url`.
  SePay's QR documentation describes `qr.sepay.vn` as a QR-generation tool and
  documents `vietqr.app/img` as the embeddable image URL.
- Payment code prefix: `DH`, configurable as `sepay.code-prefix`.
- Payment code suffix: 14 uppercase letters/digits (`A-Z`, `0-9`), generated
  from `SecureRandom` and configurable as `sepay.code-suffix-length`.
- Routes:
  - `POST /api/me/subscriptions` creates a checkout and returns payment ID,
    payment code, amount, and QR image URL.
  - `GET /api/me/payments/{paymentId}` returns the status only if the payment
    belongs to the authenticated user; return 404 otherwise.
  - `POST /api/webhooks/sepay` receives webhook notifications.
- Configuration:
  - `SEPAY_WEBHOOK_API_KEY`, bound as `sepay.webhook-api-key`.
  - `SEPAY_BANK_CODE` and `SEPAY_BANK_ACCOUNT` for QR construction.
  - The official API Key format is `Authorization: Apikey <API_KEY>`.
- Status and expiry:
  - Payment and Subscription start as `PENDING`.
  - A valid incoming transfer with the exact amount sets Payment to `PAID` and
    Subscription to `ACTIVE`.
  - Expire after 30 minutes using server time; allow a 5-minute webhook grace
    window for delayed delivery. Status checks and webhook processing perform
    transitions without a scheduler.
  - Subscription start/end dates are recalculated from the successful payment
    time.
- SePay transaction ID: reuse `Payment.providerTransactionId`, which already
  has a unique constraint.
- Under/overpayment and null/unmatched `code`: do not activate the subscription
  or mark the payment paid; log safe transaction metadata and acknowledge the
  webhook with `{"success": true}` to avoid pointless retries.

## Proposed file changes

### Create

- `Backend/src/main/java/com/prmteam7/podcasthistory/config/SepayProperties.java`
  - Follow `R2StorageProperties`: `@Component`,
    `@ConfigurationProperties(prefix = "sepay")`, JavaBean accessors.
- `Backend/src/main/java/com/prmteam7/podcasthistory/service/SepayService.java`
  - Build payment codes and QR URLs; implement owner-scoped status lookup and
    transactional webhook processing.
- `Backend/src/main/java/com/prmteam7/podcasthistory/controller/SepayController.java`
  - Expose the authenticated payment status endpoint and public webhook
    endpoint; use constructor injection and existing controller conventions.
- `Backend/src/main/java/com/prmteam7/podcasthistory/dto/request/SepayWebhookRequest.java`
  - Represent documented webhook fields, including nullable `code`,
    `transferType`, `transferAmount`, and numeric transaction `id`.
- `Backend/src/main/java/com/prmteam7/podcasthistory/dto/response/PaymentStatusItem.java`
  - Return the payment/subscription status needed for polling.
- `Backend/db/migrations/2026-10-26_sepay_payment_code.sql`
  - Add a nullable `payment_code` column and unique index to the existing
    `Payment` table. Existing rows remain valid; new SePay checkouts populate
    the field.
- `Backend/src/test/java/com/prmteam7/podcasthistory/service/SepayServiceTest.java`
  - JUnit 5 + Mockito unit tests for invalid API Key, null/unmatched code,
    amount mismatch, duplicate webhook, successful payment, and expired order.

### Modify

- `Backend/src/main/java/com/prmteam7/podcasthistory/model/Payment.java`
  - Map the new unique `paymentCode` field.
- `Backend/src/main/java/com/prmteam7/podcasthistory/repository/PaymentRepository.java`
  - Add unique-code generation lookup, locked payment-code lookup, and
    payment-owner lookup. Reuse the existing unique transaction-ID query.
- `Backend/src/main/java/com/prmteam7/podcasthistory/service/ListenerFlowService.java`
  - Keep the existing membership-plan validation and pending-order creation;
    assign `provider = "SEPAY"`, generate/store a payment code, and return the
    QR URL with the checkout response. Keep the existing cancellation rules.
- `Backend/src/main/java/com/prmteam7/podcasthistory/dto/response/ListenerResponses.java`
  - Extend `MembershipCheckoutItem` with payment code and QR URL while
    preserving its existing identifiers, amount, and statuses.
- `Backend/src/main/java/com/prmteam7/podcasthistory/config/SecurityConfig.java`
  - Permit only `POST /api/webhooks/sepay`; leave payment creation/status under
    the existing authenticated-by-default rules.
- `Backend/src/main/resources/application.properties`
  - Bind `sepay.*` properties to the environment-variable names below, with
    `sepay.qr-base-url=https://vietqr.app/img`,
    `sepay.code-prefix=DH`, and `sepay.code-suffix-length=14`.
- `Backend/.env.example`
  - Document the QR base URL, bank code, bank account, code prefix, and webhook
    API key placeholders; do not include a real key. State that prefix, suffix
    length, and allowed characters must match SePay's configured payment-code
    structure.
- `Backend/pom.xml`
  - Add only `spring-boot-starter-test` with test scope; use the version managed
    by the Spring Boot parent, with no explicit version and no other test
    libraries.

### Delete

- None.

## Request and processing flows

### Create QR checkout

1. The authenticated listener calls `POST /api/me/subscriptions` with the
   existing membership-plan request.
2. Existing plan, creator, pending-checkout, and active-membership checks remain.
3. In one transaction, create the `PENDING` Subscription and Payment, generate
   `DH` plus 14 uniformly selected characters from `A-Z` and `0-9` using
   `SecureRandom`, save it as `paymentCode`, and set provider to `SEPAY`.
4. Construct the QR image URL from the configured base URL with bank account,
   bank code, plan amount, and payment code as the transfer description. Encode
   query parameters rather than concatenating unescaped user/config data.
5. Return payment ID, payment code, amount/currency, QR image URL, and current
   statuses. Do not expose another user's payment data.

### Poll status

1. The authenticated listener calls `GET /api/me/payments/{paymentId}`.
2. Look up the payment using both payment ID and authenticated user ID. Return
   404 for missing or non-owned payments.
3. If a pending checkout has passed its 30-minute expiry, set Payment and its
   Subscription to `EXPIRED` in a transaction before returning status.

### Receive SePay webhook

1. Only `POST /api/webhooks/sepay` is public through Spring Security.
2. Require the documented `Authorization: Apikey <key>` header and compare the
   supplied key to configuration in constant time. Missing/invalid credentials
   must not process the payload. Never log the key.
3. For valid credentials, ignore non-incoming `transferType` values with a
   successful acknowledgment.
4. Trim and uppercase `code` before lookup. Ignore null/blank/unknown codes.
   Lock the matching Payment and linked Subscription in the existing
   payment-before-subscription order.
5. If already paid, or transaction `id` was already processed, do not apply
   changes again and acknowledge success. A unique provider transaction ID
   remains the database backstop against duplicate processing.
6. Use server time to determine the 30-minute payment deadline. If the webhook
    arrives after 30 minutes but within the additional 5-minute grace window,
    accept a matching payment even if a status poll has already marked the
    checkout `EXPIRED`. If it arrives after the grace window, do not activate;
    log and acknowledge for manual reconciliation.
7. If the transfer amount does not exactly match the expected payment amount,
    leave the payment pending before its deadline or expired after it; do not
    attach the transaction ID as a successful payment, log the mismatch, and
    acknowledge success.
8. For a matching amount on a pending payment, or one expired by polling but
   still within the grace window, set Payment to `PAID`, provider transaction
   ID to SePay `id`, and `paidAt` to the server time when the webhook is
   received. Activate the linked Subscription and recalculate its start/end
   dates from that same server time. Commit both updates atomically.
9. Log only non-secret metadata (code, SePay ID, amount, result).
10. Return HTTP 200 with JSON `{"success": true}` for accepted/ignored events.
    The official webhook documentation accepts HTTP 200 or 201 and requires
    this JSON success body within 30 seconds.

## Official SePay documentation referenced

- Webhook payload, response expectations, retries, and duplicate-delivery
  guidance: <https://docs.sepay.vn/tich-hop-webhooks.html>
- API Key header scheme: <https://developer.sepay.vn/vi/sepay-webhooks/xac-thuc>
- QR image URL: <https://docs.sepay.vn/tao-qr-code-vietqr-dong.html>

The documented webhook payload includes `id`, `transferType`,
`transferAmount`, `code`, and `content`; `code` may be null or empty. API Key
authentication uses `Authorization: Apikey <key>`, not Bearer authentication.

## Confirmed implementation notes

### CSRF behavior

`SecurityConfig` currently disables CSRF globally, and the API is stateless.
Permitting only the webhook does not require changing that existing setting.
Enabling CSRF for all other POST/PUT/PATCH/DELETE endpoints would change
existing behavior and may break clients that currently authenticate with JWT
without sending CSRF tokens. Preserve the current global CSRF setting and add
`permitAll` only for the webhook route, as approved.

### Unit-test dependency

No Java test files were found, and `Backend/pom.xml` currently has no test
dependency. Add only `spring-boot-starter-test` with test scope and no explicit
version (managed by the Spring Boot parent), as approved. Use JUnit 5 and
Mockito; do not add a database, Spring context, or other test library.

### Expired payment followed by a delayed webhook

The selected behavior expires an unpaid checkout after 30 minutes and allows
an additional five minutes for webhook delivery delay. Within that grace
period, a matching incoming transfer can activate a payment even if polling
already transitioned it to `EXPIRED`; after the grace period, it is logged and
acknowledged for manual reconciliation. The transfer's timestamp is not used
for expiry or `paidAt`; server time is authoritative.

## Validation

- JUnit 5 + Mockito unit tests for bad API Key, null/unmatched code, amount
  mismatch, duplicate delivery, successful activation, and expiry.
- Build the backend with Maven after implementation.
- Verify create and status routes require authentication and enforce owner
  isolation; verify the webhook route is public and validates the API Key.
- Test QR URL encoding, 30-minute expiry transitions, and transactional
  Payment/Subscription updates.
