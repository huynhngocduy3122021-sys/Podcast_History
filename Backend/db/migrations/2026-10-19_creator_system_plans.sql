-- System-wide CC plans. Channel memberships in "Membership_plan" remain separate.
-- Use this migration before startup when spring.jpa.hibernate.ddl-auto=validate.
BEGIN;

CREATE TABLE IF NOT EXISTS "Creator_system_plan" (
    plan_id uuid PRIMARY KEY,
    code varchar(60) NOT NULL UNIQUE,
    name varchar(150) NOT NULL,
    description text,
    price numeric(12,2) NOT NULL,
    currency varchar(3) NOT NULL,
    duration_days integer,
    status varchar(30) NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL
);

CREATE TABLE IF NOT EXISTS "Creator_system_plan_benefit" (
    plan_id uuid NOT NULL REFERENCES "Creator_system_plan"(plan_id),
    sort_order integer NOT NULL,
    benefit_key varchar(60) NOT NULL,
    benefit_value varchar(200) NOT NULL,
    description varchar(500),
    PRIMARY KEY (plan_id, sort_order)
);

CREATE TABLE IF NOT EXISTS "Creator_system_subscription" (
    subscription_id uuid PRIMARY KEY,
    producer_profile_id uuid NOT NULL REFERENCES "Creator_profile"(producer_profile_id),
    plan_id uuid NOT NULL REFERENCES "Creator_system_plan"(plan_id),
    start_at timestamptz NOT NULL,
    end_at timestamptz NOT NULL,
    amount numeric(12,2) NOT NULL,
    currency varchar(3) NOT NULL,
    payment_status varchar(30) NOT NULL,
    payment_reference varchar(100) NOT NULL UNIQUE,
    created_at timestamptz NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_creator_system_subscription_profile
    ON "Creator_system_subscription"(producer_profile_id);

CREATE TABLE IF NOT EXISTS "Creator_system_subscription_benefit" (
    subscription_id uuid NOT NULL REFERENCES "Creator_system_subscription"(subscription_id),
    sort_order integer NOT NULL,
    benefit_key varchar(60) NOT NULL,
    benefit_value varchar(200) NOT NULL,
    description varchar(500),
    PRIMARY KEY (subscription_id, sort_order)
);

COMMIT;
