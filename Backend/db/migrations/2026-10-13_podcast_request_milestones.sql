BEGIN;

-- Preserve existing stages while adding the agreed amount for newly-created milestones.
ALTER TABLE public."Contract_stage"
    ADD COLUMN IF NOT EXISTS amount numeric(12, 2) NOT NULL DEFAULT 0.00;

ALTER TABLE public."Payment"
    ADD COLUMN IF NOT EXISTS contract_stage_id uuid;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = to_regclass('public."Payment"')
          AND conname = 'fk_payment_contract_stage'
    ) THEN
        ALTER TABLE public."Payment"
            ADD CONSTRAINT fk_payment_contract_stage
            FOREIGN KEY (contract_stage_id)
            REFERENCES public."Contract_stage" (contract_stage_id);
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public."Milestone_submission" (
    milestone_submission_id uuid PRIMARY KEY,
    contract_stage_id uuid NOT NULL REFERENCES public."Contract_stage" (contract_stage_id),
    creator_user_id uuid NOT NULL REFERENCES public."User" (user_id),
    revision_number integer NOT NULL CHECK (revision_number > 0),
    object_key text NOT NULL,
    public_url text,
    content_type varchar(150) NOT NULL,
    submission_note text,
    submitted_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_milestone_submission_stage_id
    ON public."Milestone_submission" (contract_stage_id);

CREATE TABLE IF NOT EXISTS public."Milestone_revision" (
    milestone_revision_id uuid PRIMARY KEY,
    contract_stage_id uuid NOT NULL REFERENCES public."Contract_stage" (contract_stage_id),
    requested_by_user_id uuid NOT NULL REFERENCES public."User" (user_id),
    revision_number integer NOT NULL CHECK (revision_number > 0),
    reason text NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT uk_milestone_revision_number UNIQUE (contract_stage_id, revision_number)
);

CREATE INDEX IF NOT EXISTS idx_milestone_revision_stage_id
    ON public."Milestone_revision" (contract_stage_id);

CREATE TABLE IF NOT EXISTS public."Milestone_dispute" (
    milestone_dispute_id uuid PRIMARY KEY,
    contract_stage_id uuid NOT NULL REFERENCES public."Contract_stage" (contract_stage_id),
    raised_by_user_id uuid NOT NULL REFERENCES public."User" (user_id),
    reason text NOT NULL,
    status varchar(30) NOT NULL,
    reviewed_by_user_id uuid REFERENCES public."User" (user_id),
    decision varchar(40),
    resolution_note text,
    resolved_at timestamptz,
    created_at timestamptz NOT NULL,
    CONSTRAINT ck_milestone_dispute_resolution CHECK (
        (status = 'OPEN' AND decision IS NULL AND reviewed_by_user_id IS NULL AND resolved_at IS NULL)
        OR
        (status = 'RESOLVED' AND decision IS NOT NULL AND reviewed_by_user_id IS NOT NULL AND resolved_at IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_milestone_dispute_status
    ON public."Milestone_dispute" (status);
CREATE INDEX IF NOT EXISTS idx_milestone_dispute_stage_id
    ON public."Milestone_dispute" (contract_stage_id);

-- A milestone can have at most one payment, including under concurrent approvals.
CREATE UNIQUE INDEX IF NOT EXISTS uk_payment_contract_stage_id
    ON public."Payment" (contract_stage_id)
    WHERE contract_stage_id IS NOT NULL;

COMMIT;
