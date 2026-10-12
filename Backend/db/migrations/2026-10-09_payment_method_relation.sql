-- Align Payment_method with the 1-to-many relation shown in the ERD.
-- The current Podcast_History database has no payment rows or method rows.
BEGIN;

ALTER TABLE public."Payment_method"
    DROP CONSTRAINT IF EXISTS uk_payment_method_code,
    ADD COLUMN IF NOT EXISTS payment_id uuid;

UPDATE public."Payment_method" method
SET payment_id = payment.payment_id
FROM public."Payment" payment
WHERE method.payment_id IS NULL
  AND payment.payment_method_id = method.payment_method_id;

ALTER TABLE public."Payment_method"
    ALTER COLUMN payment_id SET NOT NULL;

ALTER TABLE public."Payment"
    DROP CONSTRAINT IF EXISTS fk_payment_payment_method,
    DROP COLUMN IF EXISTS payment_method_id;

ALTER TABLE public."Payment_method"
    DROP CONSTRAINT IF EXISTS fk_payment_method_payment;
ALTER TABLE public."Payment_method"
    ADD CONSTRAINT fk_payment_method_payment
    FOREIGN KEY (payment_id) REFERENCES public."Payment" (payment_id);

CREATE INDEX IF NOT EXISTS idx_payment_method_payment_id
    ON public."Payment_method" (payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_method_code
    ON public."Payment_method" (method_code);

COMMIT;
