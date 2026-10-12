BEGIN;

-- Remove the old direct-message report target before dropping the message tables.
DO $$
DECLARE
    check_constraint RECORD;
BEGIN
    FOR check_constraint IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = to_regclass('public."Report"')
          AND contype = 'c'
          AND pg_get_constraintdef(oid) ILIKE '%message_id%'
    LOOP
        EXECUTE format('ALTER TABLE public."Report" DROP CONSTRAINT %I', check_constraint.conname);
    END LOOP;
END
$$;

ALTER TABLE IF EXISTS public."Report" DROP COLUMN IF EXISTS message_id;

DO $$
BEGIN
    IF to_regclass('public."Report"') IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
           FROM pg_constraint
           WHERE conrelid = to_regclass('public."Report"')
             AND contype = 'c'
             AND pg_get_constraintdef(oid)
                 ILIKE '%num_nonnulls(podcast_id, comment_id, livestream_id)%'
       ) THEN
        ALTER TABLE public."Report"
            ADD CONSTRAINT ck_report_exactly_one_target
            CHECK (num_nonnulls(podcast_id, comment_id, livestream_id) = 1);
    END IF;
END
$$;

DROP TABLE IF EXISTS public.message;
DROP TABLE IF EXISTS public.conversation;
DROP TABLE IF EXISTS public.podcast_transcript;
DROP TABLE IF EXISTS public.producer_verification;

COMMIT;
