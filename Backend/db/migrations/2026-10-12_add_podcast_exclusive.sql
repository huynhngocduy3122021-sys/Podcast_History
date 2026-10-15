ALTER TABLE "Podcast"
    ADD COLUMN IF NOT EXISTS is_exclusive boolean NOT NULL DEFAULT false;
