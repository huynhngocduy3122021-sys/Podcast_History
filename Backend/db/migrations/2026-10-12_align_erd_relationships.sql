BEGIN;

-- The ERD links each livestream both to its creator profile and to its owning user.
ALTER TABLE public."Livetream" ADD COLUMN IF NOT EXISTS user_id uuid;

UPDATE public."Livetream" AS livestream
SET user_id = creator.user_id
FROM public."Creator_profile" AS creator
WHERE livestream.producer_profile_id = creator.producer_profile_id
  AND livestream.user_id IS NULL;

ALTER TABLE public."Livetream" ALTER COLUMN user_id SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = to_regclass('public."Livetream"')
          AND conname = 'fk_livestream_user'
    ) THEN
        ALTER TABLE public."Livetream"
            ADD CONSTRAINT fk_livestream_user
            FOREIGN KEY (user_id) REFERENCES public."User" (user_id);
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_livestream_user_id
    ON public."Livetream" (user_id);

-- Nested-comment parent links are not in the ERD or requested comment flow.
ALTER TABLE public."Comment" DROP COLUMN IF EXISTS parent_comment_id;

COMMIT;
