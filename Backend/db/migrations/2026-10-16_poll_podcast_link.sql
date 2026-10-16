BEGIN;
ALTER TABLE public."Polll" ALTER COLUMN series_id DROP NOT NULL;
ALTER TABLE public."Polll" ADD COLUMN IF NOT EXISTS podcast_id uuid;
ALTER TABLE public."Polll" ALTER COLUMN podcast_id DROP NOT NULL;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public."Polll"'::regclass AND conname = 'fk_poll_podcast'
    ) THEN
        ALTER TABLE public."Polll"
            ADD CONSTRAINT fk_poll_podcast FOREIGN KEY (podcast_id)
            REFERENCES public."Podcast" (podcast_id);
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_poll_podcast_id ON public."Polll" (podcast_id);
COMMIT;
