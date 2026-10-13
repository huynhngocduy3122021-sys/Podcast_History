-- Keep every existing podcast while making series an optional grouping.
-- Run this once against Podcast_History before starting the updated backend.
BEGIN;

ALTER TABLE "Podcast" ADD COLUMN IF NOT EXISTS producer_profile_id uuid;
ALTER TABLE "Podcast" ADD COLUMN IF NOT EXISTS category_id uuid;

UPDATE "Podcast" AS podcast
SET producer_profile_id = series.producer_profile_id,
    category_id = series.category_id
FROM "Series" AS series
WHERE podcast.series_id = series.series_id
  AND (podcast.producer_profile_id IS NULL OR podcast.category_id IS NULL);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM "Podcast"
        WHERE producer_profile_id IS NULL OR category_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Podcast has rows without creator or category; migration stopped';
    END IF;
END $$;

ALTER TABLE "Podcast" ALTER COLUMN producer_profile_id SET NOT NULL;
ALTER TABLE "Podcast" ALTER COLUMN category_id SET NOT NULL;
ALTER TABLE "Podcast" ALTER COLUMN series_id DROP NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_podcast_creator_profile'
            AND conrelid = '"Podcast"'::regclass) THEN
        ALTER TABLE "Podcast" ADD CONSTRAINT fk_podcast_creator_profile
            FOREIGN KEY (producer_profile_id) REFERENCES "Creator_profile" (producer_profile_id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_podcast_category'
            AND conrelid = '"Podcast"'::regclass) THEN
        ALTER TABLE "Podcast" ADD CONSTRAINT fk_podcast_category
            FOREIGN KEY (category_id) REFERENCES "Category" (category_id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_podcast_producer_profile_id ON "Podcast" (producer_profile_id);
CREATE INDEX IF NOT EXISTS idx_podcast_category_id ON "Podcast" (category_id);
COMMIT;
