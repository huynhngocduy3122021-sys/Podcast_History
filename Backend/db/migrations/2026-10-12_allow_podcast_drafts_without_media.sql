-- Podcast rows are created as drafts before the Creator uploads the episode video.
ALTER TABLE "Podcast" ALTER COLUMN media_url DROP NOT NULL;
ALTER TABLE "Podcast" ALTER COLUMN media_type DROP NOT NULL;
