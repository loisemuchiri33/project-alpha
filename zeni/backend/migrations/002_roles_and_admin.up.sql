-- +goose Up
-- +goose StatementBegin
ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'user';
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role) WHERE deleted_at IS NULL;

ALTER TABLE loans ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
ALTER TABLE loans ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ;
ALTER TABLE loans ADD COLUMN IF NOT EXISTS rejected_by UUID REFERENCES users(id);

COMMENT ON COLUMN users.role IS 'user | agent | admin | superadmin';
-- +goose StatementEnd
