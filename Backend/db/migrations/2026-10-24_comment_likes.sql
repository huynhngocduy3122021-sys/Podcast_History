-- Additive migration for likes on comments. With ddl-auto=update, Hibernate can also create this table.
BEGIN;
CREATE TABLE IF NOT EXISTS "Comment_like" (
    comment_like_id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES "User"(user_id),
    comment_id uuid NOT NULL REFERENCES "Comment"(comment_id),
    created_at timestamptz NOT NULL,
    CONSTRAINT uk_comment_like_user_id_comment_id UNIQUE (user_id, comment_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS uk_comment_like_user_id_comment_id
    ON "Comment_like"(user_id, comment_id);
CREATE INDEX IF NOT EXISTS idx_comment_like_user_id ON "Comment_like"(user_id);
CREATE INDEX IF NOT EXISTS idx_comment_like_comment_id ON "Comment_like"(comment_id);
COMMIT;
