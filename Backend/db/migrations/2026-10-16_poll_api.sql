-- Existing ERD tables are retained: Polll = question; Polll_questions = answer options.
-- No poll, option or response is removed by this migration.
BEGIN;
ALTER TABLE public."Polll" ALTER COLUMN series_id DROP NOT NULL;
ALTER TABLE public."Polll" ADD COLUMN IF NOT EXISTS row_version bigint NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_poll_creator_status_created
    ON public."Polll" (producer_profile_id, status, created_at DESC, poll_id DESC);
CREATE INDEX IF NOT EXISTS idx_poll_vote_poll_created
    ON public."Poll_votes" (poll_id, created_at DESC, poll_vote_id DESC);
COMMIT;
