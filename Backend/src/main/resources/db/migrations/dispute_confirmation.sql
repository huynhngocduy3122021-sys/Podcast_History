-- Non-destructive schema for three-day counterparty confirmation.
ALTER TABLE "Contract_dispute" ADD COLUMN IF NOT EXISTS opponent_confirmed_at timestamptz;
ALTER TABLE "Milestone_dispute" ADD COLUMN IF NOT EXISTS opponent_confirmed_at timestamptz;
ALTER TABLE "Contract_dispute" ADD COLUMN IF NOT EXISTS listener_win_action varchar(30);
ALTER TABLE "Milestone_dispute" ADD COLUMN IF NOT EXISTS listener_win_action varchar(30);
ALTER TABLE "Milestone_dispute" ADD COLUMN IF NOT EXISTS previous_stage_status varchar(30);
