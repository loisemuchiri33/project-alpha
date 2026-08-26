package repositories

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/zeni-lending/backend/internal/loan"
	"github.com/zeni-lending/backend/pkg/logger"
)

type LoanRepo struct {
	pool   *pgxpool.Pool
	logger *logger.Logger
}

func NewLoanRepo(pool *pgxpool.Pool, log *logger.Logger) *LoanRepo {
	return &LoanRepo{pool: pool, logger: log}
}

func (r *LoanRepo) Create(ctx context.Context, l *loan.Loan) error {
	q := `INSERT INTO loans (id,user_id,amount,interest_rate,duration_days,status,total_repayment,
		amount_paid,disbursed_at,due_date,completed_at,purpose,late_fee,is_auto_limit,created_at,updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)`
	_, err := r.pool.Exec(ctx, q, l.ID, l.UserID, l.Amount, l.InterestRate, l.DurationDays, l.Status,
		l.TotalRepayment, l.AmountPaid, l.DisbursedAt, l.DueDate, l.CompletedAt, l.Purpose, l.LateFee,
		l.IsAutoLimit, l.CreatedAt, l.UpdatedAt)
	return err
}

func (r *LoanRepo) FindByID(ctx context.Context, id uuid.UUID) (*loan.Loan, error) {
	var l loan.Loan
	err := r.pool.QueryRow(ctx, `SELECT id,user_id,amount,interest_rate,duration_days,status,total_repayment,
		amount_paid,disbursed_at,due_date,completed_at,purpose,late_fee,is_auto_limit,created_at,updated_at
		FROM loans WHERE id=$1`, id).Scan(&l.ID, &l.UserID, &l.Amount, &l.InterestRate, &l.DurationDays,
		&l.Status, &l.TotalRepayment, &l.AmountPaid, &l.DisbursedAt, &l.DueDate, &l.CompletedAt,
		&l.Purpose, &l.LateFee, &l.IsAutoLimit, &l.CreatedAt, &l.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, errors.New("loan not found")
	}
	return &l, err
}

func (r *LoanRepo) FindByUserID(ctx context.Context, userID uuid.UUID) ([]*loan.Loan, error) {
	rows, err := r.pool.Query(ctx, `SELECT id,user_id,amount,interest_rate,duration_days,status,total_repayment,
		amount_paid,disbursed_at,due_date,completed_at,purpose,late_fee,is_auto_limit,created_at,updated_at
		FROM loans WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*loan.Loan
	for rows.Next() {
		var l loan.Loan
		if err := rows.Scan(&l.ID, &l.UserID, &l.Amount, &l.InterestRate, &l.DurationDays, &l.Status,
			&l.TotalRepayment, &l.AmountPaid, &l.DisbursedAt, &l.DueDate, &l.CompletedAt, &l.Purpose,
			&l.LateFee, &l.IsAutoLimit, &l.CreatedAt, &l.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, &l)
	}
	return out, rows.Err()
}

func (r *LoanRepo) FindActiveByUserID(ctx context.Context, userID uuid.UUID) (*loan.Loan, error) {
	var l loan.Loan
	err := r.pool.QueryRow(ctx, `SELECT id,user_id,amount,interest_rate,duration_days,status,total_repayment,
		amount_paid,disbursed_at,due_date,completed_at,purpose,late_fee,is_auto_limit,created_at,updated_at
		FROM loans WHERE user_id=$1 AND status IN ('pending','active') ORDER BY created_at DESC LIMIT 1`, userID).
		Scan(&l.ID, &l.UserID, &l.Amount, &l.InterestRate, &l.DurationDays, &l.Status, &l.TotalRepayment,
			&l.AmountPaid, &l.DisbursedAt, &l.DueDate, &l.CompletedAt, &l.Purpose, &l.LateFee, &l.IsAutoLimit,
			&l.CreatedAt, &l.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	return &l, err
}

func (r *LoanRepo) Update(ctx context.Context, l *loan.Loan) error {
	l.UpdatedAt = time.Now()
	_, err := r.pool.Exec(ctx, `UPDATE loans SET status=$2,total_repayment=$3,amount_paid=$4,disbursed_at=$5,
		due_date=$6,completed_at=$7,late_fee=$8,updated_at=$9,
		approved_by=$10,rejection_reason=$11,rejected_by=$12,rejected_at=$13 WHERE id=$1`,
		l.ID, l.Status, l.TotalRepayment, l.AmountPaid, l.DisbursedAt, l.DueDate, l.CompletedAt, l.LateFee, l.UpdatedAt,
		l.ApprovedBy, nullIfEmpty(l.RejectionReason), l.RejectedBy, l.RejectedAt)
	return err
}

func nullIfEmpty(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}

// ListByStatus returns loans with borrower info for the ops queue.
func (r *LoanRepo) ListByStatus(ctx context.Context, status string, limit int) ([]*loan.Loan, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	q := `SELECT l.id,l.user_id,l.amount,l.interest_rate,l.duration_days,l.status,l.total_repayment,
		l.amount_paid,l.disbursed_at,l.due_date,l.completed_at,COALESCE(l.purpose,''),l.late_fee,l.is_auto_limit,
		l.created_at,l.updated_at,
		u.phone, COALESCE(u.first_name,'') || ' ' || COALESCE(u.last_name,''), COALESCE(u.kyc_status,'')
		FROM loans l
		JOIN users u ON u.id = l.user_id
		WHERE ($1 = '' OR l.status = $1)
		ORDER BY l.created_at DESC LIMIT $2`
	rows, err := r.pool.Query(ctx, q, status, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*loan.Loan
	for rows.Next() {
		var l loan.Loan
		if err := rows.Scan(&l.ID, &l.UserID, &l.Amount, &l.InterestRate, &l.DurationDays, &l.Status,
			&l.TotalRepayment, &l.AmountPaid, &l.DisbursedAt, &l.DueDate, &l.CompletedAt, &l.Purpose,
			&l.LateFee, &l.IsAutoLimit, &l.CreatedAt, &l.UpdatedAt,
			&l.BorrowerPhone, &l.BorrowerName, &l.BorrowerKYC); err != nil {
			return nil, err
		}
		out = append(out, &l)
	}
	return out, rows.Err()
}

func (r *LoanRepo) CountByStatus(ctx context.Context, status string) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM loans WHERE status=$1`, status).Scan(&n)
	return n, err
}

func (r *LoanRepo) GetUserLoanStats(ctx context.Context, userID uuid.UUID) (*loan.UserLoanStats, error) {
	var s loan.UserLoanStats
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*), COALESCE(SUM(amount),0), COALESCE(SUM(amount_paid),0),
		COUNT(*) FILTER (WHERE status IN ('pending','active')),
		COUNT(*) FILTER (WHERE status='completed' AND completed_at <= due_date),
		COUNT(*) FILTER (WHERE status='completed' AND completed_at > due_date),
		COALESCE(AVG(EXTRACT(DAY FROM completed_at - due_date)) FILTER (WHERE status='completed'),0)
		FROM loans WHERE user_id=$1`, userID).Scan(
		&s.TotalLoans, &s.TotalBorrowed, &s.TotalRepaid, &s.ActiveLoans,
		&s.OnTimePayments, &s.LatePayments, &s.AverageRepaymentDays)
	return &s, err
}

func (r *LoanRepo) FindOverdueLoans(ctx context.Context) ([]*loan.Loan, error) {
	rows, err := r.pool.Query(ctx, `SELECT id,user_id,amount,interest_rate,duration_days,status,total_repayment,
		amount_paid,disbursed_at,due_date,completed_at,purpose,late_fee,is_auto_limit,created_at,updated_at
		FROM loans WHERE status='active' AND due_date < $1 ORDER BY due_date ASC`, time.Now())
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*loan.Loan
	for rows.Next() {
		var l loan.Loan
		if err := rows.Scan(&l.ID, &l.UserID, &l.Amount, &l.InterestRate, &l.DurationDays, &l.Status,
			&l.TotalRepayment, &l.AmountPaid, &l.DisbursedAt, &l.DueDate, &l.CompletedAt, &l.Purpose,
			&l.LateFee, &l.IsAutoLimit, &l.CreatedAt, &l.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, &l)
	}
	return out, rows.Err()
}

func (r *LoanRepo) GetPortfolioStats(ctx context.Context) (map[string]interface{}, error) {
	var activeLoans, completedLoans, overdueLoans int
	var activePrincipal, activeOutstanding, totalRepaid, avgLoanSize, overdueAmount float64
	err := r.pool.QueryRow(ctx, `SELECT
		COUNT(*) FILTER (WHERE status='active'),
		COALESCE(SUM(amount) FILTER (WHERE status='active'),0),
		COALESCE(SUM(total_repayment-amount_paid) FILTER (WHERE status='active'),0),
		COUNT(*) FILTER (WHERE status='completed'),
		COALESCE(SUM(amount_paid) FILTER (WHERE status='completed'),0),
		COALESCE(AVG(amount) FILTER (WHERE status='active'),0),
		COUNT(*) FILTER (WHERE status='active' AND due_date < NOW()),
		COALESCE(SUM(total_repayment-amount_paid) FILTER (WHERE status='active' AND due_date < NOW()),0)
		FROM loans`).Scan(
		&activeLoans, &activePrincipal, &activeOutstanding, &completedLoans,
		&totalRepaid, &avgLoanSize, &overdueLoans, &overdueAmount)
	if err != nil {
		return nil, err
	}
	var pendingLoans int
	_ = r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM loans WHERE status='pending'`).Scan(&pendingLoans)
	defaultRate := 0.0
	if activeLoans+completedLoans > 0 {
		defaultRate = float64(overdueLoans) / float64(activeLoans+completedLoans)
	}
	return map[string]interface{}{
		"active_loans": activeLoans, "active_principal": activePrincipal,
		"active_outstanding": activeOutstanding, "completed_loans": completedLoans,
		"total_disbursed": activePrincipal, "total_collected": totalRepaid,
		"total_repaid": totalRepaid, "avg_loan_size": avgLoanSize,
		"overdue_loans": overdueLoans, "overdue_amount": overdueAmount,
		"pending_loans": pendingLoans, "default_rate": defaultRate,
	}, nil
}
