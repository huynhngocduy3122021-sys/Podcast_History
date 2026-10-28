CREATE TABLE IF NOT EXISTS "Checkout_payment" (
  checkout_id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES "User"(user_id),
  creator_subscription_id uuid REFERENCES "Creator_system_subscription"(subscription_id),
  purpose varchar(30) NOT NULL,
  amount numeric(12,2) NOT NULL,
  currency varchar(3) NOT NULL,
  payment_code varchar(64) NOT NULL UNIQUE,
  provider_transaction_id varchar(180) UNIQUE,
  status varchar(30) NOT NULL,
  paid_at timestamptz,
  created_at timestamptz NOT NULL,
  CONSTRAINT chk_checkout_payment_purpose CHECK (
    (purpose = 'WALLET_TOPUP' AND creator_subscription_id IS NULL) OR
    (purpose = 'CREATOR_PLAN' AND creator_subscription_id IS NOT NULL)
  ),
  CONSTRAINT chk_checkout_payment_amount CHECK (amount > 0)
);
