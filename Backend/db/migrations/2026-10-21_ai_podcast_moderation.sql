-- Keep one record per AI analysis attempt. Admin decisions remain in "Moderation_Review".
BEGIN;

CREATE TABLE IF NOT EXISTS "AI_Moderation_Result" (
    moderation_result_id uuid PRIMARY KEY,
    podcast_id uuid NOT NULL REFERENCES "Podcast"(podcast_id),
    model_name varchar(120) NOT NULL,
    model_version varchar(60),
    overall_label varchar(40) NOT NULL,
    confidence_score numeric(5,4),
    raw_result jsonb,
    processed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    status varchar(30) NOT NULL DEFAULT 'PENDING',
    recommendation varchar(30),
    reason text,
    source_hash varchar(64),
    media_key text,
    error_message text
);

ALTER TABLE "AI_Moderation_Result" ADD COLUMN IF NOT EXISTS status varchar(30) NOT NULL DEFAULT 'COMPLETED';
ALTER TABLE "AI_Moderation_Result" ADD COLUMN IF NOT EXISTS recommendation varchar(30);
ALTER TABLE "AI_Moderation_Result" ADD COLUMN IF NOT EXISTS reason text;
ALTER TABLE "AI_Moderation_Result" ADD COLUMN IF NOT EXISTS source_hash varchar(64);
ALTER TABLE "AI_Moderation_Result" ADD COLUMN IF NOT EXISTS media_key text;
ALTER TABLE "AI_Moderation_Result" ADD COLUMN IF NOT EXISTS error_message text;
ALTER TABLE "AI_Moderation_Result" ALTER COLUMN processed_at DROP NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ai_moderation_result_podcast_id
    ON "AI_Moderation_Result"(podcast_id);
CREATE INDEX IF NOT EXISTS idx_ai_moderation_result_podcast_created
    ON "AI_Moderation_Result"(podcast_id, created_at DESC);

COMMIT;
