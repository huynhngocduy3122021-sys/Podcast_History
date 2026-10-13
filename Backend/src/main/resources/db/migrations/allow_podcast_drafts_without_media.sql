-- A Creator creates the draft before uploading its video.
-- Re-running these statements preserves all existing podcast data.
ALTER TABLE "Podcast" ALTER COLUMN media_url DROP NOT NULL;
ALTER TABLE "Podcast" ALTER COLUMN media_type DROP NOT NULL;
