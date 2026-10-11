-- Apply once to the existing Podcast_History PostgreSQL database before
-- starting the backend. Table and column renames preserve existing data.
BEGIN;

DO $$
BEGIN
    IF to_regclass('public."User"') IS NULL AND to_regclass('public.user') IS NOT NULL THEN
        ALTER TABLE public."user" RENAME TO "User";
    END IF;

    IF to_regclass('public.creator_profile') IS NULL AND to_regclass('public.producer_profile') IS NOT NULL THEN
        ALTER TABLE public.producer_profile RENAME TO creator_profile;
    END IF;

    IF to_regclass('public.series_response') IS NULL AND to_regclass('public.request_response') IS NOT NULL THEN
        ALTER TABLE public.request_response RENAME TO series_response;
    END IF;

    IF to_regclass('public.poll_questions') IS NULL AND to_regclass('public.poll_option') IS NOT NULL THEN
        ALTER TABLE public.poll_option RENAME TO poll_questions;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'series_response'
          AND column_name = 'request_response_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'series_response'
          AND column_name = 'series_response_id'
    ) THEN
        ALTER TABLE public.series_response RENAME COLUMN request_response_id TO series_response_id;
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'payment'
          AND column_name = 'payment_method'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'payment'
          AND column_name = 'payment_method_code'
    ) THEN
        ALTER TABLE public.payment RENAME COLUMN payment_method TO payment_method_code;
    END IF;
END $$;

ALTER TABLE public.series_response
    ADD COLUMN IF NOT EXISTS producer_profile_id uuid;

UPDATE public.series_response response
SET producer_profile_id = request.producer_profile_id
FROM public.series_request request
WHERE response.series_request_id = request.series_request_id
  AND response.producer_profile_id IS NULL;

ALTER TABLE public.series_response
    ALTER COLUMN producer_profile_id SET NOT NULL;

ALTER TABLE public.series_response
    DROP CONSTRAINT IF EXISTS fk_series_response_creator_profile;
ALTER TABLE public.series_response
    ADD CONSTRAINT fk_series_response_creator_profile
    FOREIGN KEY (producer_profile_id)
    REFERENCES public.creator_profile (producer_profile_id);

CREATE TABLE IF NOT EXISTS public.payment_method (
    payment_method_id uuid PRIMARY KEY,
    method_code varchar(40) NOT NULL,
    display_name varchar(100) NOT NULL,
    is_active boolean NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT uk_payment_method_code UNIQUE (method_code)
);

CREATE TABLE IF NOT EXISTS public.contract (
    contract_id uuid PRIMARY KEY,
    user_id uuid NOT NULL,
    producer_profile_id uuid NOT NULL,
    series_response_id uuid NOT NULL UNIQUE,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    CONSTRAINT fk_contract_user FOREIGN KEY (user_id)
        REFERENCES public."User" (user_id),
    CONSTRAINT fk_contract_creator_profile FOREIGN KEY (producer_profile_id)
        REFERENCES public.creator_profile (producer_profile_id),
    CONSTRAINT fk_contract_series_response FOREIGN KEY (series_response_id)
        REFERENCES public.series_response (series_response_id)
);

CREATE INDEX IF NOT EXISTS idx_contract_user_id ON public.contract (user_id);
CREATE INDEX IF NOT EXISTS idx_contract_producer_profile_id ON public.contract (producer_profile_id);

CREATE TABLE IF NOT EXISTS public.contract_stage (
    contract_stage_id uuid PRIMARY KEY,
    contract_id uuid NOT NULL,
    stage_name varchar(150) NOT NULL,
    description text,
    stage_order integer NOT NULL,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    CONSTRAINT uk_contract_stage_order UNIQUE (contract_id, stage_order),
    CONSTRAINT fk_contract_stage_contract FOREIGN KEY (contract_id)
        REFERENCES public.contract (contract_id)
);

CREATE INDEX IF NOT EXISTS idx_contract_stage_contract_id ON public.contract_stage (contract_id);

ALTER TABLE public.payment
    ADD COLUMN IF NOT EXISTS payment_method_id uuid,
    ADD COLUMN IF NOT EXISTS contract_stage_id uuid;

INSERT INTO public.payment_method
    (payment_method_id, method_code, display_name, is_active, created_at)
SELECT gen_random_uuid(), COALESCE(NULLIF(BTRIM(payment_method_code), ''), 'LEGACY_UNKNOWN'),
       COALESCE(NULLIF(BTRIM(payment_method_code), ''), 'Legacy payment method'), TRUE, now()
FROM public.payment
ON CONFLICT (method_code) DO NOTHING;

UPDATE public.payment payment
SET payment_method_id = method.payment_method_id,
    payment_method_code = COALESCE(NULLIF(BTRIM(payment.payment_method_code), ''), 'LEGACY_UNKNOWN')
FROM public.payment_method method
WHERE payment.payment_method_id IS NULL
  AND method.method_code = COALESCE(NULLIF(BTRIM(payment.payment_method_code), ''), 'LEGACY_UNKNOWN');

ALTER TABLE public.payment
    ALTER COLUMN payment_method_id SET NOT NULL,
    ALTER COLUMN payment_method_code DROP NOT NULL;

ALTER TABLE public.payment DROP CONSTRAINT IF EXISTS payment_check;
ALTER TABLE public.payment ADD CONSTRAINT payment_check CHECK (
    (subscription_id IS NOT NULL AND series_request_id IS NULL AND contract_stage_id IS NULL)
    OR (subscription_id IS NULL AND series_request_id IS NOT NULL AND contract_stage_id IS NULL)
    OR (subscription_id IS NULL AND series_request_id IS NULL AND contract_stage_id IS NOT NULL)
);

ALTER TABLE public.payment DROP CONSTRAINT IF EXISTS fk_payment_payment_method;
ALTER TABLE public.payment ADD CONSTRAINT fk_payment_payment_method
    FOREIGN KEY (payment_method_id) REFERENCES public.payment_method (payment_method_id);

ALTER TABLE public.payment DROP CONSTRAINT IF EXISTS fk_payment_contract_stage;
ALTER TABLE public.payment ADD CONSTRAINT fk_payment_contract_stage
    FOREIGN KEY (contract_stage_id) REFERENCES public.contract_stage (contract_stage_id);

CREATE INDEX IF NOT EXISTS idx_payment_contract_stage_id ON public.payment (contract_stage_id);

ALTER TABLE public.wallet_transaction
    ADD COLUMN IF NOT EXISTS contract_id uuid;

CREATE UNIQUE INDEX IF NOT EXISTS uk_wallet_transaction_contract_id
    ON public.wallet_transaction (contract_id) WHERE contract_id IS NOT NULL;

ALTER TABLE public.wallet_transaction DROP CONSTRAINT IF EXISTS fk_wallet_transaction_contract;
ALTER TABLE public.wallet_transaction ADD CONSTRAINT fk_wallet_transaction_contract
    FOREIGN KEY (contract_id) REFERENCES public.contract (contract_id);

ALTER TABLE public.wallet_transaction DROP CONSTRAINT IF EXISTS wallet_transaction_check;
ALTER TABLE public.wallet_transaction ADD CONSTRAINT wallet_transaction_check CHECK (
    amount > 0 AND (user_wallet_id IS NOT NULL OR system_wallet_id IS NOT NULL OR contract_id IS NOT NULL)
);

COMMIT;
