package repositories

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/zeni-lending/backend/internal/auth"
)

// StaffMember is a safe projection of staff users for the admin workers table.
type StaffMember struct {
	ID         uuid.UUID  `json:"id"`
	Phone      string     `json:"phone"`
	Email      string     `json:"email"`
	FirstName  string     `json:"first_name"`
	LastName   string     `json:"last_name"`
	Role       string     `json:"role"`
	IsActive   bool       `json:"is_active"`
	LastLogin  *time.Time `json:"last_login_at,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
}

func (r *UserRepo) ListStaff(ctx context.Context) ([]StaffMember, error) {
	if r.pool == nil {
		return []StaffMember{}, nil
	}
	q := `
		SELECT id, phone, COALESCE(email,''), first_name, last_name, COALESCE(role,'user'),
			is_active, last_login_at, created_at
		FROM users
		WHERE role IN ('admin','agent','superadmin') AND deleted_at IS NULL
		ORDER BY
			CASE role WHEN 'superadmin' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END,
			created_at ASC`
	rows, err := r.pool.Query(ctx, q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []StaffMember
	for rows.Next() {
		var s StaffMember
		if err := rows.Scan(&s.ID, &s.Phone, &s.Email, &s.FirstName, &s.LastName, &s.Role, &s.IsActive, &s.LastLogin, &s.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	if out == nil {
		out = []StaffMember{}
	}
	return out, rows.Err()
}

func (r *UserRepo) SetLastLogin(ctx context.Context, userID uuid.UUID) error {
	if r.pool == nil {
		return nil
	}
	_, err := r.pool.Exec(ctx, `UPDATE users SET last_login_at=$2, updated_at=$2 WHERE id=$1`, userID, time.Now())
	return err
}

func (r *UserRepo) DeactivateStaff(ctx context.Context, userID uuid.UUID) error {
	if r.pool == nil {
		return errors.New("database offline")
	}
	// Never deactivate the last superadmin
	var n int
	_ = r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM users WHERE role='superadmin' AND is_active=true AND deleted_at IS NULL AND id<>$1`, userID).Scan(&n)
	var role string
	err := r.pool.QueryRow(ctx, `SELECT role FROM users WHERE id=$1 AND deleted_at IS NULL`, userID).Scan(&role)
	if errors.Is(err, pgx.ErrNoRows) {
		return auth.ErrUserNotFound
	}
	if err != nil {
		return err
	}
	if role == "superadmin" && n == 0 {
		return errors.New("cannot deactivate the only CEO account")
	}
	_, err = r.pool.Exec(ctx, `UPDATE users SET is_active=false, updated_at=$2 WHERE id=$1`, userID, time.Now())
	return err
}
