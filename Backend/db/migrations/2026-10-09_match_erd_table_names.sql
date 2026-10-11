-- Apply to preserve the capitalization and labels used by the latest ERD.
-- PostgreSQL table renames preserve existing rows and foreign-key targets.
BEGIN;

DO $$
BEGIN
    IF to_regclass('public."Role"') IS NULL AND to_regclass('public.role') IS NOT NULL THEN ALTER TABLE public.role RENAME TO "Role"; END IF;
    IF to_regclass('public."Notification"') IS NULL AND to_regclass('public.notification') IS NOT NULL THEN ALTER TABLE public.notification RENAME TO "Notification"; END IF;
    IF to_regclass('public."Creator_profile"') IS NULL AND to_regclass('public.creator_profile') IS NOT NULL THEN ALTER TABLE public.creator_profile RENAME TO "Creator_profile"; END IF;
    IF to_regclass('public."Series"') IS NULL AND to_regclass('public.series') IS NOT NULL THEN ALTER TABLE public.series RENAME TO "Series"; END IF;
    IF to_regclass('public."Category"') IS NULL AND to_regclass('public.category') IS NOT NULL THEN ALTER TABLE public.category RENAME TO "Category"; END IF;
    IF to_regclass('public."Podcast"') IS NULL AND to_regclass('public.podcast') IS NOT NULL THEN ALTER TABLE public.podcast RENAME TO "Podcast"; END IF;
    IF to_regclass('public."Podcast_reference"') IS NULL AND to_regclass('public.podcast_reference') IS NOT NULL THEN ALTER TABLE public.podcast_reference RENAME TO "Podcast_reference"; END IF;
    IF to_regclass('public."Comment"') IS NULL AND to_regclass('public.comment') IS NOT NULL THEN ALTER TABLE public.comment RENAME TO "Comment"; END IF;
    IF to_regclass('public."Postcast_like"') IS NULL AND to_regclass('public.podcast_like') IS NOT NULL THEN ALTER TABLE public.podcast_like RENAME TO "Postcast_like"; END IF;
    IF to_regclass('public."Save_postcast"') IS NULL AND to_regclass('public.saved_podcast') IS NOT NULL THEN ALTER TABLE public.saved_podcast RENAME TO "Save_postcast"; END IF;
    IF to_regclass('public."Listening_History"') IS NULL AND to_regclass('public.listening_history') IS NOT NULL THEN ALTER TABLE public.listening_history RENAME TO "Listening_History"; END IF;
    IF to_regclass('public."Membership_plan"') IS NULL AND to_regclass('public.membership_plan') IS NOT NULL THEN ALTER TABLE public.membership_plan RENAME TO "Membership_plan"; END IF;
    IF to_regclass('public."Subcription"') IS NULL AND to_regclass('public.subscription') IS NOT NULL THEN ALTER TABLE public.subscription RENAME TO "Subcription"; END IF;
    IF to_regclass('public."Payment"') IS NULL AND to_regclass('public.payment') IS NOT NULL THEN ALTER TABLE public.payment RENAME TO "Payment"; END IF;
    IF to_regclass('public."Series_request"') IS NULL AND to_regclass('public.series_request') IS NOT NULL THEN ALTER TABLE public.series_request RENAME TO "Series_request"; END IF;
    IF to_regclass('public."Series_response"') IS NULL AND to_regclass('public.series_response') IS NOT NULL THEN ALTER TABLE public.series_response RENAME TO "Series_response"; END IF;
    IF to_regclass('public."Payment_method"') IS NULL AND to_regclass('public.payment_method') IS NOT NULL THEN ALTER TABLE public.payment_method RENAME TO "Payment_method"; END IF;
    IF to_regclass('public."Contract"') IS NULL AND to_regclass('public.contract') IS NOT NULL THEN ALTER TABLE public.contract RENAME TO "Contract"; END IF;
    IF to_regclass('public."Contract_stage"') IS NULL AND to_regclass('public.contract_stage') IS NOT NULL THEN ALTER TABLE public.contract_stage RENAME TO "Contract_stage"; END IF;
    IF to_regclass('public."Wallet_Transaction"') IS NULL AND to_regclass('public.wallet_transaction') IS NOT NULL THEN ALTER TABLE public.wallet_transaction RENAME TO "Wallet_Transaction"; END IF;
    IF to_regclass('public."Livetream"') IS NULL AND to_regclass('public.livestream') IS NOT NULL THEN ALTER TABLE public.livestream RENAME TO "Livetream"; END IF;
    IF to_regclass('public."Follow"') IS NULL AND to_regclass('public.follow') IS NOT NULL THEN ALTER TABLE public.follow RENAME TO "Follow"; END IF;
    IF to_regclass('public."Polll"') IS NULL AND to_regclass('public.poll') IS NOT NULL THEN ALTER TABLE public.poll RENAME TO "Polll"; END IF;
    IF to_regclass('public."Polll_questions"') IS NULL AND to_regclass('public.poll_questions') IS NOT NULL THEN ALTER TABLE public.poll_questions RENAME TO "Polll_questions"; END IF;
    IF to_regclass('public."Poll_votes"') IS NULL AND to_regclass('public.poll_vote') IS NOT NULL THEN ALTER TABLE public.poll_vote RENAME TO "Poll_votes"; END IF;
    IF to_regclass('public."AI_Moderation_Result"') IS NULL AND to_regclass('public.ai_moderation_result') IS NOT NULL THEN ALTER TABLE public.ai_moderation_result RENAME TO "AI_Moderation_Result"; END IF;
    IF to_regclass('public."Moderation_Review"') IS NULL AND to_regclass('public.moderation_review') IS NOT NULL THEN ALTER TABLE public.moderation_review RENAME TO "Moderation_Review"; END IF;
    IF to_regclass('public."Report"') IS NULL AND to_regclass('public.report') IS NOT NULL THEN ALTER TABLE public.report RENAME TO "Report"; END IF;
    IF to_regclass('public."User_wallet"') IS NULL AND to_regclass('public.user_wallet') IS NOT NULL THEN ALTER TABLE public.user_wallet RENAME TO "User_wallet"; END IF;
    IF to_regclass('public."Withdrawal_request"') IS NULL AND to_regclass('public.withdrawal_request') IS NOT NULL THEN ALTER TABLE public.withdrawal_request RENAME TO "Withdrawal_request"; END IF;
    IF to_regclass('public."Withdrawal_review"') IS NULL AND to_regclass('public.withdrawal_review') IS NOT NULL THEN ALTER TABLE public.withdrawal_review RENAME TO "Withdrawal_review"; END IF;
END $$;

COMMIT;
