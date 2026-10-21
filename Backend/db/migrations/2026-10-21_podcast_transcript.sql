BEGIN;
CREATE TABLE IF NOT EXISTS "Podcast_Transcript" (
    transcript_id uuid PRIMARY KEY,
    podcast_id uuid NOT NULL REFERENCES "Podcast"(podcast_id),
    media_key text NOT NULL,
    status varchar(30) NOT NULL DEFAULT 'PENDING',
    language varchar(20),
    model_name varchar(120) NOT NULL,
    full_text text,
    segments jsonb,
    error_message text,
    processed_at timestamptz,
    processing_started_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_podcast_transcript_media UNIQUE (podcast_id, media_key)
);
ALTER TABLE "Podcast_Transcript" ADD COLUMN IF NOT EXISTS processing_started_at timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS uq_podcast_transcript_media
    ON "Podcast_Transcript"(podcast_id, media_key);
CREATE INDEX IF NOT EXISTS idx_podcast_transcript_podcast_id
    ON "Podcast_Transcript"(podcast_id);
ALTER TABLE "AI_Moderation_Result"
    ADD COLUMN IF NOT EXISTS transcript_id uuid REFERENCES "Podcast_Transcript"(transcript_id);
ALTER TABLE "AI_Moderation_Result"
    ADD COLUMN IF NOT EXISTS transcript_hash varchar(64);
CREATE INDEX IF NOT EXISTS idx_ai_moderation_transcript_id
    ON "AI_Moderation_Result"(transcript_id);
COMMIT;
