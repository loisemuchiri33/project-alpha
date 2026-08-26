package loan

import (
	"context"
	"fmt"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/zeni-lending/backend/internal/config"
	"github.com/zeni-lending/backend/pkg/logger"
)

var (
	ErrInsufficientLimit  = fmt.Errorf("loan amount exceeds available limit")
	ErrExistingActiveLoan = fmt.Errorf("user has an active or pending loan")
	ErrMinimumLoanAmount  = fmt.Errorf("minimum loan amount is KES 500")
	ErrLoanNotFound       = fmt.Errorf("loan not found")
	ErrInvalidDuration    = fmt.Errorf("loan tenor must be exactly 30 days")
	ErrKYCRequired        = fmt.Errorf("kyc verification required before applying for a loan")
	ErrPhoneNotVerified   = fmt.Errorf("phone verification required before applying for a loan")
	ErrUserInactive       = fmt.Errorf("user account is not active")
	ErrNotApproved        = fmt.Errorf("loan is not in approved state for disbursement")
)

// Product rule: all ZENI loans are single-instalment, due in 30 days only.
const FixedLoanTenorDays = 30

// BorrowerProfile is the minimum borrower data the engine needs for policy gates.
type BorrowerProfile struct {
	IsActive        bool
	IsPhoneVerified bool
	KYCStatus       string
	CreditScore     int
	LoanLimit       float64
}

type UserLookup interface {
	GetBorrower(ctx context.Context, userID uuid.UUID) (*BorrowerProfile, error)
}

type Engine struct {
	cfg    *config.Config
	logger *logger.Logger
	repo   LoanRepository
	users  UserLookup
}

type LoanRepository interface {
	Create(ctx context.Context, loan *Loan) error
	FindByID(ctx context.Context, id uuid.UUID) (*Loan, error)
	FindByUserID(ctx context.Context, userID uuid.UUID) ([]*Loan, error)
	FindActiveByUserID(ctx context.Context, userID uuid.UUID) (*Loan, error)
	Update(ctx context.Context, loan *Loan) error
	GetUserLoanStats(ctx context.Context, userID uuid.UUID) (*UserLoanStats, error)
}

type Loan struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	UserID          uuid.UUID  `json:"user_id" db:"user_id"`
	Amount          float64    `json:"amount" db:"amount"`
	InterestRate    float64    `json:"interest_rate" db:"interest_rate"`
	DurationDays    int        `json:"duration_days" db:"duration_days"`
	Status          string     `json:"status" db:"status"`
	TotalRepayment  float64    `json:"total_repayment" db:"total_repayment"`
	AmountPaid      float64    `json:"amount_paid" db:"amount_paid"`
	DisbursedAt     *time.Time `json:"disbursed_at" db:"disbursed_at"`
	DueDate         *time.Time `json:"due_date" db:"due_date"`
	CompletedAt     *time.Time `json:"completed_at" db:"completed_at"`
	Purpose         string     `json:"purpose" db:"purpose"`
	LateFee         float64    `json:"late_fee" db:"late_fee"`
	IsAutoLimit     bool       `json:"is_auto_limit" db:"is_auto_limit"`
	ApprovedBy      *uuid.UUID `json:"approved_by,omitempty" db:"approved_by"`
	RejectionReason string     `json:"rejection_reason,omitempty" db:"rejection_reason"`
	RejectedBy      *uuid.UUID `json:"rejected_by,omitempty" db:"rejected_by"`
	RejectedAt      *time.Time `json:"rejected_at,omitempty" db:"rejected_at"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at" db:"updated_at"`
	BorrowerPhone   string     `json:"borrower_phone,omitempty" db:"-"`
	BorrowerName    string     `json:"borrower_name,omitempty" db:"-"`
	BorrowerKYC     string     `json:"borrower_kyc,omitempty" db:"-"`
}

type UserLoanStats struct {
	TotalLoans           int     `json:"total_loans"`
	TotalBorrowed        float64 `json:"total_borrowed"`
	TotalRepaid          float64 `json:"total_repaid"`
	ActiveLoans          int     `json:"active_loans"`
	OnTimePayments       int     `json:"on_time_payments"`
	LatePayments         int     `json:"late_payments"`
	CurrentLimit         float64 `json:"current_limit"`
	AverageRepaymentDays int     `json:"average_repayment_days"`
}

var limitTiers = []struct {
	minScore int
	limit    float64
}{
	{500, 5000}, {550, 10000}, {600, 15000}, {650, 20000},
	{700, 25000}, {750, 30000}, {800, 35000},
}

var interestRates = map[string]float64{"low_risk": 0.12, "medium_risk": 0.15, "high_risk": 0.20}

func NewEngine(cfg *config.Config, logger *logger.Logger, repo LoanRepository) *Engine {
	return &Engine{cfg: cfg, logger: logger, repo: repo}
}

func (e *Engine) SetUserLookup(u UserLookup) {
	e.users = u
}

type Application struct {
	UserID       uuid.UUID
	Amount       float64
	DurationDays int
	Purpose      string
}

func (e *Engine) Apply(ctx context.Context, app *Application) (*Loan, error) {
	if app.Amount < 500 {
		return nil, ErrMinimumLoanAmount
	}
	if app.DurationDays != 0 && app.DurationDays != FixedLoanTenorDays {
		return nil, ErrInvalidDuration
	}
	app.DurationDays = FixedLoanTenorDays

	if e.users != nil {
		b, err := e.users.GetBorrower(ctx, app.UserID)
		if err != nil {
			return nil, ErrUserInactive
		}
		if b == nil || !b.IsActive {
			return nil, ErrUserInactive
		}
		if !b.IsPhoneVerified {
			return nil, ErrPhoneNotVerified
		}
		// Accept verified/approved KYC statuses used across the stack.
		switch b.KYCStatus {
		case "verified", "approved", "complete", "completed":
			// ok
		default:
			return nil, ErrKYCRequired
		}
		limit := b.LoanLimit
		if limit <= 0 {
			limit = e.CalculateLimit(b.CreditScore)
		}
		if limit <= 0 {
			return nil, ErrInsufficientLimit
		}
		if app.Amount > limit {
			return nil, ErrInsufficientLimit
		}
	}

	existing, _ := e.repo.FindActiveByUserID(ctx, app.UserID)
	if existing != nil {
		return nil, ErrExistingActiveLoan
	}

	stats, _ := e.repo.GetUserLoanStats(ctx, app.UserID)
	if stats == nil {
		stats = &UserLoanStats{}
	}

	interestRate := interestRates["medium_risk"]
	if stats.OnTimePayments >= 5 && stats.LatePayments == 0 {
		interestRate = interestRates["low_risk"]
	} else if stats.LatePayments > 2 {
		interestRate = interestRates["high_risk"]
	}

	totalRepayment := e.calculateRepayment(app.Amount, interestRate, FixedLoanTenorDays)

	// Due date is set at disbursement, not at application.
	loan := &Loan{
		ID: uuid.New(), UserID: app.UserID, Amount: app.Amount,
		InterestRate: interestRate, DurationDays: FixedLoanTenorDays,
		Status: "pending", TotalRepayment: totalRepayment, AmountPaid: 0,
		Purpose: app.Purpose, LateFee: 0,
		CreatedAt: time.Now(), UpdatedAt: time.Now(),
	}
	if err := e.repo.Create(ctx, loan); err != nil {
		return nil, fmt.Errorf("failed to create loan: %w", err)
	}
	e.logger.Info("loan application submitted", "loan_id", loan.ID, "amount", app.Amount)
	return loan, nil
}

// Approve marks a pending loan as approved only. Disbursement is a separate step
// (B2C) so underwriting cannot auto-move cash.
func (e *Engine) Approve(ctx context.Context, id uuid.UUID, approverID uuid.UUID) (*Loan, error) {
	loan, err := e.repo.FindByID(ctx, id)
	if err != nil {
		return nil, ErrLoanNotFound
	}
	if loan.Status != "pending" {
		return nil, fmt.Errorf("loan is not pending approval")
	}
	now := time.Now()
	loan.Status = "approved"
	loan.ApprovedBy = &approverID
	loan.UpdatedAt = now
	if err := e.repo.Update(ctx, loan); err != nil {
		return nil, fmt.Errorf("failed to approve loan: %w", err)
	}
	e.logger.Info("loan approved (awaiting disbursement)", "loan_id", loan.ID, "approver", approverID)
	return loan, nil
}

// MarkDisbursementPending records that B2C was initiated; cash not yet confirmed.
func (e *Engine) MarkDisbursementPending(ctx context.Context, id uuid.UUID) (*Loan, error) {
	loan, err := e.repo.FindByID(ctx, id)
	if err != nil {
		return nil, ErrLoanNotFound
	}
	if loan.Status != "approved" && loan.Status != "disbursement_failed" {
		return nil, ErrNotApproved
	}
	loan.Status = "disbursement_pending"
	loan.UpdatedAt = time.Now()
	if err := e.repo.Update(ctx, loan); err != nil {
		return nil, fmt.Errorf("failed to mark disbursement pending: %w", err)
	}
	e.logger.Info("loan disbursement pending (awaiting B2C result)", "loan_id", loan.ID)
	return loan, nil
}

// MarkDisbursed is called after a successful B2C disbursement (or confirmed result).
func (e *Engine) MarkDisbursed(ctx context.Context, id uuid.UUID) (*Loan, error) {
	loan, err := e.repo.FindByID(ctx, id)
	if err != nil {
		return nil, ErrLoanNotFound
	}
	if loan.Status != "approved" && loan.Status != "disbursement_pending" {
		return nil, ErrNotApproved
	}
	now := time.Now()
	loan.Status = "active"
	loan.DisbursedAt = &now
	due := now.AddDate(0, 0, loan.DurationDays)
	loan.DueDate = &due
	loan.UpdatedAt = now
	if err := e.repo.Update(ctx, loan); err != nil {
		return nil, fmt.Errorf("failed to mark loan disbursed: %w", err)
	}
	e.logger.Info("loan disbursed", "loan_id", loan.ID)
	return loan, nil
}

// MarkDisbursementFailed records a failed B2C attempt while keeping the approval.
func (e *Engine) MarkDisbursementFailed(ctx context.Context, id uuid.UUID, reason string) (*Loan, error) {
	loan, err := e.repo.FindByID(ctx, id)
	if err != nil {
		return nil, ErrLoanNotFound
	}
	if loan.Status != "approved" && loan.Status != "disbursement_pending" {
		return nil, ErrNotApproved
	}
	loan.Status = "disbursement_failed"
	loan.RejectionReason = reason
	loan.UpdatedAt = time.Now()
	if err := e.repo.Update(ctx, loan); err != nil {
		return nil, err
	}
	return loan, nil
}

func (e *Engine) Reject(ctx context.Context, id uuid.UUID, rejectorID uuid.UUID, reason string) (*Loan, error) {
	if reason == "" {
		reason = "rejected by underwriter"
	}
	loan, err := e.repo.FindByID(ctx, id)
	if err != nil {
		return nil, ErrLoanNotFound
	}
	if loan.Status != "pending" {
		return nil, fmt.Errorf("loan is not pending approval")
	}
	now := time.Now()
	loan.Status = "rejected"
	loan.RejectionReason = reason
	loan.RejectedBy = &rejectorID
	loan.RejectedAt = &now
	loan.UpdatedAt = now
	if err := e.repo.Update(ctx, loan); err != nil {
		return nil, fmt.Errorf("failed to reject loan: %w", err)
	}
	e.logger.Info("loan rejected", "loan_id", loan.ID, "rejector", rejectorID)
	return loan, nil
}

func (e *Engine) RecordPayment(ctx context.Context, repayment *struct {
	LoanID         uuid.UUID
	Amount         float64
	PaymentMethod  string
	TransactionRef string
	PaidAt         time.Time
}) (*Loan, error) {
	loan, err := e.repo.FindByID(ctx, repayment.LoanID)
	if err != nil {
		return nil, ErrLoanNotFound
	}
	if loan.Status != "active" {
		return nil, fmt.Errorf("loan is not active")
	}

	loan.AmountPaid += repayment.Amount
	loan.UpdatedAt = time.Now()

	if loan.AmountPaid >= loan.TotalRepayment {
		now := time.Now()
		loan.Status = "completed"
		loan.CompletedAt = &now
	}
	if err := e.repo.Update(ctx, loan); err != nil {
		return nil, fmt.Errorf("failed to record payment: %w", err)
	}
	e.logger.Info("payment recorded", "loan_id", loan.ID, "amount", repayment.Amount, "ref", repayment.TransactionRef)
	return loan, nil
}

func (e *Engine) CalculateLimit(creditScore int) float64 {
	if creditScore < 500 {
		return 0
	}
	var limit float64
	for _, tier := range limitTiers {
		if creditScore >= tier.minScore {
			limit = tier.limit
		}
	}
	return limit
}

func (e *Engine) CalculateLateFee(loan *Loan) float64 {
	if loan.DueDate == nil || time.Now().Before(*loan.DueDate) {
		return 0
	}
	daysLate := int(time.Now().Sub(*loan.DueDate).Hours() / 24)
	outstanding := loan.TotalRepayment - loan.AmountPaid
	lateFeeRate := math.Min(float64(daysLate)/7*0.05, 0.30)
	return math.Round(outstanding*lateFeeRate*100) / 100
}

func (e *Engine) calculateRepayment(principal, rate float64, days int) float64 {
	interest := principal * rate * float64(days) / 365.0
	total := principal + interest
	if principal >= 1000 {
		total += 100
	}
	return math.Round(total*100) / 100
}
