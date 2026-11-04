-- Adds the identifier used by the backend-owned channel membership defaults.
-- Hibernate ddl-auto=update also adds this column in local development.
ALTER TABLE "Membership_plan"
    ADD COLUMN IF NOT EXISTS template_code varchar(30);
