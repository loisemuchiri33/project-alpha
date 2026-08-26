-- +goose Up
-- +goose StatementBegin

ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'user';
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_unique
  ON users (lower(email))
  WHERE email IS NOT NULL AND email <> '' AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_audit_resource ON audit_logs(resource);
CREATE INDEX IF NOT EXISTS idx_audit_user_created ON audit_logs(user_id, created_at DESC);

-- Loan lifecycle: pending → approved → active (after B2C) | rejected | disbursement_failed
COMMENT ON COLUMN users.role IS 'user | agent | admin | superadmin';

-- Payment intents bind STK checkout ids before callback posts ledger
CREATE TABLE IF NOT EXISTS payment_intents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    loan_id UUID NOT NULL REFERENCES loans(id),
    amount DECIMAL(15,2) NOT NULL,
    phone_number VARCHAR(15) NOT NULL,
    checkout_request_id VARCHAR(80) UNIQUE,
    merchant_request_id VARCHAR(80),
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_payment_intents_loan ON payment_intents(loan_id);
CREATE INDEX IF NOT EXISTS idx_payment_intents_status ON payment_intents(status);

-- +goose StatementEnd
