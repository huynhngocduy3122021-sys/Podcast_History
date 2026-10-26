BEGIN;

ALTER TABLE public."Payment"
    ADD COLUMN IF NOT EXISTS payment_code varchar(64);

CREATE UNIQUE INDEX IF NOT EXISTS uk_payment_payment_code
    ON public."Payment" (payment_code);

COMMIT;
