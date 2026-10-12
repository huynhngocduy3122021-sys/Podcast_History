-- Add hashed, rotating refresh-token storage without dropping application data.
CREATE TABLE IF NOT EXISTS auth_refresh_token (
    refresh_token_id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES "User" (user_id) ON DELETE CASCADE,
    token_hash varchar(64) NOT NULL,
    token_family_id uuid NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_auth_refresh_token_hash UNIQUE (token_hash)
);

CREATE INDEX IF NOT EXISTS idx_auth_refresh_token_user_id
    ON auth_refresh_token (user_id);

CREATE INDEX IF NOT EXISTS idx_auth_refresh_token_family_id
    ON auth_refresh_token (token_family_id);

CREATE INDEX IF NOT EXISTS idx_auth_refresh_token_expires_at
    ON auth_refresh_token (expires_at);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ck_user_password_hash_bcrypt'
          AND conrelid = '"User"'::regclass
    ) THEN
        ALTER TABLE "User"
            ADD CONSTRAINT ck_user_password_hash_bcrypt
            CHECK (password_hash ~ '^\$2[aby]\$[0-9]{2}\$[./A-Za-z0-9]{53}$');
    END IF;
END
$$;
