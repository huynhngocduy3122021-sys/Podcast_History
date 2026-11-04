-- Apply through the deployment migration process when Hibernate ddl-auto is disabled.
CREATE TABLE IF NOT EXISTS contract_chat_message (
    message_id uuid PRIMARY KEY,
    contract_id uuid NOT NULL REFERENCES "Contract"(contract_id),
    sender_user_id uuid NOT NULL REFERENCES "User"(user_id),
    client_message_id uuid NOT NULL,
    content text NOT NULL CHECK (length(trim(content)) BETWEEN 1 AND 2000),
    created_at timestamptz NOT NULL,
    CONSTRAINT uk_contract_chat_client_message UNIQUE (contract_id, sender_user_id, client_message_id)
);

CREATE INDEX IF NOT EXISTS idx_contract_chat_history
    ON contract_chat_message (contract_id, created_at);
