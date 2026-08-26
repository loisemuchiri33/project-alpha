package repositories

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/zeni-lending/backend/internal/auth"
	"github.com/zeni-lending/backend/pkg/logger"
)

type UserRepo struct {
	pool   *pgxpool.Pool
	logger *logger.Logger
}

func NewUserRepo(pool *pgxpool.Pool, log *logger.Logger) *UserRepo {
	return &UserRepo{pool: pool, logger: log}
}

func (r *UserRepo) Create(ctx context.Context, user *auth.User) error {
	if user.Role == "" {
		user.Role = "user"
	}
	q := `INSERT INTO users (id, phone, email, first_name, last_name, password_hash, role,
		kyc_status, credit_score, risk_level, loan_limit, is_active, is_phone_verified, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)`
	_, err := r.pool.Exec(ctx, q,
		user.ID, user.Phone, user.Email, user.FirstName, user.LastName, user.PasswordHash, user.Role,
		user.KYCStatus, user.CreditScore, user.RiskLevel, user.LoanLimit, user.IsActive,
		user.IsPhoneVerified, user.CreatedAt, user.UpdatedAt,
	)
	return err
}

func (r *UserRepo) FindByPhone(ctx context.Context, phone string) (*auth.User, error) {
	q := `SELECT id, phone, email, first_name, last_name, password_hash, COALESCE(role,'user'), kyc_status, credit_score,
		risk_level, loan_limit, is_active, is_phone_verified, created_at, updated_at
		FROM users WHERE phone=$1 AND deleted_at IS NULL`
	var u auth.User
	err := r.pool.QueryRow(ctx, q, phone).Scan(
		&u.ID, &u.Phone, &u.Email, &u.FirstName, &u.LastName, &u.PasswordHash, &u.Role,
		&u.KYCStatus, &u.CreditScore, &u.RiskLevel, &u.LoanLimit, &u.IsActive,
		&u.IsPhoneVerified, &u.CreatedAt, &u.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, auth.ErrUserNotFound
	}
	return &u, err
}

func (r *UserRepo) FindByID(ctx context.Context, id uuid.UUID) (*auth.User, error) {
	q := `SELECT id, phone, email, first_name, last_name, password_hash, COALESCE(role,'user'), kyc_status, credit_score,
		risk_level, loan_limit, is_active, is_phone_verified, created_at, updated_at
		FROM users WHERE id=$1 AND deleted_at IS NULL`
	var u auth.User
	err := r.pool.QueryRow(ctx, q, id).Scan(
		&u.ID, &u.Phone, &u.Email, &u.FirstName, &u.LastName, &u.PasswordHash, &u.Role,
		&u.KYCStatus, &u.CreditScore, &u.RiskLevel, &u.LoanLimit, &u.IsActive,
		&u.IsPhoneVerified, &u.CreatedAt, &u.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, auth.ErrUserNotFound
	}
	return &u, err
}

func (r *UserRepo) Update(ctx context.Context, user *auth.User) error {
	user.UpdatedAt = time.Now()
	q := `UPDATE users SET email=$2, first_name=$3, last_name=$4, kyc_status=$5, credit_score=$6,
		risk_level=$7, loan_limit=$8, is_active=$9, is_phone_verified=$10, role=$11, updated_at=$12
		WHERE id=$1 AND deleted_at IS NULL`
	_, err := r.pool.Exec(ctx, q, user.ID, user.Email, user.FirstName, user.LastName,
		user.KYCStatus, user.CreditScore, user.RiskLevel, user.LoanLimit, user.IsActive,
		user.IsPhoneVerified, user.Role, user.UpdatedAt)
	return err
}

func (r *UserRepo) UpdatePassword(ctx context.Context, userID uuid.UUID, hash string) error {
	_, err := r.pool.Exec(ctx, `UPDATE users SET password_hash=$2, updated_at=$3 WHERE id=$1`,
		userID, hash, time.Now())
	return err
}

func (r *UserRepo) CountActiveUsers(ctx context.Context) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM users WHERE is_active=true AND deleted_at IS NULL`).Scan(&n)
	return n, err
}

func (r *UserRepo) CountPendingKYC(ctx context.Context) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM users WHERE kyc_status IN ('pending','submitted') AND deleted_at IS NULL`).Scan(&n)
	return n, err
}
