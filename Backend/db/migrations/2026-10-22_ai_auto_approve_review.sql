-- An AI approval has no human reviewer; its moderation_result_id identifies the decision source.
ALTER TABLE "Moderation_Review" ALTER COLUMN reviewer_user_id DROP NOT NULL;
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'moderation_review_ai_actor_check'
          AND conrelid = '"Moderation_Review"'::regclass
    ) THEN
        ALTER TABLE "Moderation_Review" ADD CONSTRAINT moderation_review_ai_actor_check
            CHECK (reviewer_user_id IS NOT NULL OR
                   (moderation_result_id IS NOT NULL AND podcast_id IS NOT NULL AND decision = 'APPROVED'));
    END IF;
END $$;
