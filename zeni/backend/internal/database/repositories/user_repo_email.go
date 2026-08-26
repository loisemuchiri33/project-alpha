package repositories

import (
	"context"
	"errors"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/zeni-lending/backend/internal/auth"
)

func (r *UserRepo) FindByEmail(ctx context.Context, email string) (*auth.User, error) {
	if r.pool == nil {
		return nil, auth.ErrUserNotFound
	}
	email = strings.ToLower(strings.TrimSpace(email))
	q := `SELECT id, phone, email, first_name, last_name, password_hash, COALESCE(role,'user'), kyc_status, credit_score,
		risk_level, loan_limit, is_active, is_phone_verified, created_at, updated_at
		FROM users WHERE lower(email)=$1 AND deleted_at IS NULL`
	var u auth.User
	err := r.pool.QueryRow(ctx, q, email).Scan(
		&u.ID, &u.Phone, &u.Email, &u.FirstName, &u.LastName, &u.PasswordHash, &u.Role,
		&u.KYCStatus, &u.CreditScore, &u.RiskLevel, &u.LoanLimit, &u.IsActive,
		&u.IsPhoneVerified, &u.CreatedAt, &u.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, auth.ErrUserNotFound
	}
	return &u, err
}
