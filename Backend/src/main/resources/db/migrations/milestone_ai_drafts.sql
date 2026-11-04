-- Apply to a dedicated deployment database before enabling AI-gated handoff when ddl-auto is disabled.
CREATE TABLE IF NOT EXISTS milestone_draft (
    draft_id uuid PRIMARY KEY,
    contract_stage_id uuid NOT NULL REFERENCES "Contract_stage"(contract_stage_id),
    creator_user_id uuid NOT NULL REFERENCES "User"(user_id),
    draft_number integer NOT NULL,
    object_key text NOT NULL,
    content_type varchar(150) NOT NULL,
    note text,
    status varchar(30) NOT NULL,
    ai_label varchar(20),
    ai_recommendation varchar(20),
    ai_confidence numeric(5,4),
    ai_reason varchar(2000),
    error_message varchar(500),
    attempt_token uuid,
    processing_started_at timestamptz,
    reviewed_at timestamptz,
    delivered_at timestamptz,
    created_at timestamptz NOT NULL,
    CONSTRAINT uk_milestone_draft_number UNIQUE (contract_stage_id, draft_number)
);
CREATE INDEX IF NOT EXISTS idx_milestone_draft_review ON milestone_draft(status, processing_started_at);
