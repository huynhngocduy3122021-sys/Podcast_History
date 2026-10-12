BEGIN;

-- Keep the source payment on wallet-ledger entries before removing the
-- intermediate producer_earning table. Payment_method remains attached to
-- Payment as the channel used to make that payment.
ALTER TABLE public."Wallet_Transaction"
    ADD COLUMN IF NOT EXISTS payment_id uuid;

DO $$
BEGIN
    IF to_regclass('public.producer_earning') IS NOT NULL THEN
        EXECUTE $sql$
            UPDATE public."Wallet_Transaction" AS wallet_transaction
            SET payment_id = producer_earning.payment_id
            FROM public.producer_earning AS producer_earning
            WHERE wallet_transaction.producer_earning_id = producer_earning.producer_earning_id
              AND wallet_transaction.payment_id IS NULL
        $sql$;
    END IF;
END
$$;

-- Remove check constraints that still depend on the support-table columns.
DO $$
DECLARE
    check_constraint RECORD;
BEGIN
    FOR check_constraint IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = to_regclass('public."Wallet_Transaction"')
          AND contype = 'c'
          AND (
              pg_get_constraintdef(oid) ILIKE '%system_wallet_id%'
              OR pg_get_constraintdef(oid) ILIKE '%producer_earning_id%'
          )
    LOOP
        EXECUTE format(
            'ALTER TABLE public."Wallet_Transaction" DROP CONSTRAINT %I',
            check_constraint.conname
        );
    END LOOP;
END
$$;

ALTER TABLE public."Wallet_Transaction"
    DROP COLUMN IF EXISTS system_wallet_id,
    DROP COLUMN IF EXISTS producer_earning_id;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = to_regclass('public."Wallet_Transaction"')
          AND conname = 'fk_wallet_transaction_payment'
    ) THEN
        ALTER TABLE public."Wallet_Transaction"
            ADD CONSTRAINT fk_wallet_transaction_payment
            FOREIGN KEY (payment_id) REFERENCES public."Payment" (payment_id);
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_wallet_transaction_payment_id
    ON public."Wallet_Transaction" (payment_id);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = to_regclass('public."Wallet_Transaction"')
          AND conname = 'wallet_transaction_check'
    ) THEN
        ALTER TABLE public."Wallet_Transaction"
            ADD CONSTRAINT wallet_transaction_check CHECK (
                amount > 0
                AND (
                    user_wallet_id IS NOT NULL
                    OR contract_id IS NOT NULL
                    OR withdrawal_request_id IS NOT NULL
                    OR payment_id IS NOT NULL
                )
            );
    END IF;
END
$$;

DROP TABLE IF EXISTS public.membership_benefit;
DROP TABLE IF EXISTS public.producer_earning;
DROP TABLE IF EXISTS public.system_wallet;

COMMIT;
