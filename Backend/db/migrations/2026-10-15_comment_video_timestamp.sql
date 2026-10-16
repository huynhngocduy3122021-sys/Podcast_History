-- Additive migration: existing comments retain NULL (unknown playback position).
BEGIN;
ALTER TABLE public."Comment" ADD COLUMN IF NOT EXISTS timestamp_seconds integer;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public."Comment"'::regclass
          AND conname = 'ck_comment_timestamp_nonnegative'
    ) THEN
        ALTER TABLE public."Comment"
            ADD CONSTRAINT ck_comment_timestamp_nonnegative
            CHECK (timestamp_seconds IS NULL OR timestamp_seconds >= 0);
    END IF;
END $$;
COMMIT;
