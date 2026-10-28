-- Non-destructive PostgreSQL schema for request contracts. Apply through the deployment
-- migration process before enabling the new API when Hibernate ddl-auto is disabled.
ALTER TABLE "Contract_stage" ADD COLUMN IF NOT EXISTS due_at timestamptz;

CREATE TABLE IF NOT EXISTS contract_escrow (
    contract_escrow_id uuid PRIMARY KEY,
    series_request_id uuid NOT NULL UNIQUE REFERENCES "Series_request"(series_request_id),
    contract_id uuid UNIQUE REFERENCES "Contract"(contract_id),
    idempotency_key uuid NOT NULL UNIQUE,
    budget numeric(12,2) NOT NULL CHECK (budget > 0),
    remaining numeric(12,2) NOT NULL CHECK (remaining >= 0 AND remaining <= budget),
    product_type varchar(8) NOT NULL CHECK (product_type IN ('AUDIO', 'VIDEO')),
    file_format varchar(60) NOT NULL,
    duration_description varchar(120) NOT NULL,
    acceptance_criteria text NOT NULL,
    auto_accept_enabled boolean NOT NULL,
    contract_version integer,
    content_hash varchar(64),
    content_snapshot text,
    creator_signed_at timestamptz,
    listener_signed_at timestamptz,
    terminated_at timestamptz,
    created_at timestamptz NOT NULL
);
