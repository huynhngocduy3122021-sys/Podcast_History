-- Additive migration for Admin/Staff features. No existing rows or tables are deleted.
-- Apply to PostgreSQL Podcast_History before startup when ddl-auto is validate.
BEGIN;
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS token_version bigint NOT NULL DEFAULT 0;
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS row_version bigint NOT NULL DEFAULT 0;
ALTER TABLE "Podcast" ADD COLUMN IF NOT EXISTS row_version bigint NOT NULL DEFAULT 0;
ALTER TABLE "Report" ADD COLUMN IF NOT EXISTS assigned_to_id uuid REFERENCES "User"(user_id);
ALTER TABLE "Withdrawal_request" ADD COLUMN IF NOT EXISTS funds_reserved boolean NOT NULL DEFAULT false;
ALTER TABLE "Withdrawal_request" ADD COLUMN IF NOT EXISTS payout_reference varchar(180);
ALTER TABLE "Payment" ADD COLUMN IF NOT EXISTS refund_reference varchar(180);
ALTER TABLE "Payment" ADD COLUMN IF NOT EXISTS refunded_at timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS uk_withdrawal_payout_reference ON "Withdrawal_request"(payout_reference);
CREATE UNIQUE INDEX IF NOT EXISTS uk_payment_refund_reference ON "Payment"(refund_reference);
CREATE TABLE IF NOT EXISTS "Admin_audit" (
    audit_id uuid PRIMARY KEY, actor_id uuid NOT NULL REFERENCES "User"(user_id),
    action varchar(60) NOT NULL, resource_type varchar(40) NOT NULL, resource_id uuid NOT NULL,
    note text, created_at timestamptz NOT NULL
);
CREATE TABLE IF NOT EXISTS "Podcast_appeal" (
    appeal_id uuid PRIMARY KEY, podcast_id uuid NOT NULL REFERENCES "Podcast"(podcast_id),
    applicant_id uuid NOT NULL REFERENCES "User"(user_id), reason text NOT NULL, status varchar(30) NOT NULL,
    note text, reviewer_id uuid REFERENCES "User"(user_id), created_at timestamptz NOT NULL, resolved_at timestamptz
);
CREATE TABLE IF NOT EXISTS "Contract_dispute" (
    dispute_id uuid PRIMARY KEY, contract_id uuid NOT NULL REFERENCES "Contract"(contract_id),
    opened_by_id uuid NOT NULL REFERENCES "User"(user_id), reason text NOT NULL,
    previous_contract_status varchar(30) NOT NULL, status varchar(30) NOT NULL, decision varchar(30),
    note text, reviewer_id uuid REFERENCES "User"(user_id), created_at timestamptz NOT NULL, resolved_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_admin_audit_resource ON "Admin_audit"(resource_type,resource_id);
CREATE INDEX IF NOT EXISTS idx_admin_audit_created ON "Admin_audit"(created_at);
CREATE INDEX IF NOT EXISTS idx_podcast_appeal_status ON "Podcast_appeal"(status,created_at);
CREATE INDEX IF NOT EXISTS idx_contract_dispute_status ON "Contract_dispute"(status,created_at);
COMMIT;
