-- Podcasts are identified by podcast_id; Category and Series keep their slugs.
ALTER TABLE "Podcast" DROP CONSTRAINT IF EXISTS uk_podcast_series_id_slug;
ALTER TABLE "Podcast" DROP COLUMN IF EXISTS slug;
