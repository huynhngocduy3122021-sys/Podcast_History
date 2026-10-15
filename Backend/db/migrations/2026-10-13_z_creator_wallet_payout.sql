-- Apply after 2026-10-13_podcast_request_milestones.sql on existing databases.
BEGIN;

ALTER TABLE public."User_wallet"
    ADD COLUMN IF NOT EXISTS held_balance numeric(14, 2) NOT NULL DEFAULT 0.00;

ALTER TABLE public."Withdrawal_request"
    ADD COLUMN IF NOT EXISTS payout_account_reference varchar(255),
    ADD COLUMN IF NOT EXISTS provider_reference varchar(180);

ALTER TABLE public."Wallet_Transaction"
    ADD COLUMN IF NOT EXISTS held_balance_after numeric(14, 2);

CREATE TABLE IF NOT EXISTS public."Creator_payout_account" (
    creator_payout_account_id uuid PRIMARY KEY,
    producer_profile_id uuid NOT NULL REFERENCES public."Creator_profile" (producer_profile_id),
    payout_method varchar(40) NOT NULL,
    account_reference varchar(255) NOT NULL,
    account_masked varchar(160) NOT NULL,
    currency char(3) NOT NULL,
    is_verified boolean NOT NULL DEFAULT false,
    is_active boolean NOT NULL DEFAULT true,
    verified_at timestamptz,
    created_at timestamptz NOT NULL,
    CONSTRAINT ck_creator_payout_account_verified_at CHECK (
        (is_verified = false) OR verified_at IS NOT NULL
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_creator_payout_account_reference
    ON public."Creator_payout_account" (account_reference);
CREATE INDEX IF NOT EXISTS idx_creator_payout_account_creator
    ON public."Creator_payout_account" (producer_profile_id);
CREATE INDEX IF NOT EXISTS idx_withdrawal_request_status_requested_at
    ON public."Withdrawal_request" (status, requested_at);
CREATE UNIQUE INDEX IF NOT EXISTS uk_wallet_transaction_release_payment
    ON public."Wallet_Transaction" (payment_id)
    WHERE payment_id IS NOT NULL AND transaction_type = 'RELEASE_FUNDS';
CREATE UNIQUE INDEX IF NOT EXISTS uk_wallet_transaction_withdrawal_type
    ON public."Wallet_Transaction" (withdrawal_request_id, transaction_type)
    WHERE withdrawal_request_id IS NOT NULL
      AND transaction_type IN ('WITHDRAWAL_HOLD', 'WITHDRAWAL_REFUND');

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = to_regclass('public."User_wallet"')
          AND conname = 'ck_user_wallet_balances_nonnegative'
    ) THEN
        ALTER TABLE public."User_wallet"
            ADD CONSTRAINT ck_user_wallet_balances_nonnegative
            CHECK (balance >= 0 AND held_balance >= 0);
    END IF;

END
$$;

COMMIT;
