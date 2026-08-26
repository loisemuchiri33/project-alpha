package repositories

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/zeni-lending/backend/pkg/logger"
)

type PaymentIntent struct {
	ID                 uuid.UUID  `json:"id"`
	UserID             uuid.UUID  `json:"user_id"`
	LoanID             uuid.UUID  `json:"loan_id"`
	Amount             float64    `json:"amount"`
	PhoneNumber        string     `json:"phone_number"`
	CheckoutRequestID  string     `json:"checkout_request_id,omitempty"`
	MerchantRequestID  string     `json:"merchant_request_id,omitempty"`
	Status             string     `json:"status"`
	MpesaReceiptNumber string     `json:"mpesa_receipt_number,omitempty"`
	CreatedAt          time.Time  `json:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at"`
	CompletedAt        *time.Time `json:"completed_at,omitempty"`
}

type PaymentIntentRepo struct {
	pool   *pgxpool.Pool
	logger *logger.Logger
}

func NewPaymentIntentRepo(pool *pgxpool.Pool, log *logger.Logger) *PaymentIntentRepo {
	return &PaymentIntentRepo{pool: pool, logger: log}
}

func (r *PaymentIntentRepo) Create(ctx context.Context, p *PaymentIntent) error {
	if r.pool == nil {
		return errors.New("database offline")
	}
	if p.ID == uuid.Nil {
		p.ID = uuid.New()
	}
	now := time.Now()
	p.CreatedAt = now
	p.UpdatedAt = now
	if p.Status == "" {
		p.Status = "pending"
	}
	_, err := r.pool.Exec(ctx, `
		INSERT INTO payment_intents (id,user_id,loan_id,amount,phone_number,checkout_request_id,merchant_request_id,status,created_at,updated_at)
		VALUES ($1,$2,$3,$4,$5,NULLIF($6,''),NULLIF($7,''),$8,$9,$10)`,
		p.ID, p.UserID, p.LoanID, p.Amount, p.PhoneNumber, p.CheckoutRequestID, p.MerchantRequestID, p.Status, p.CreatedAt, p.UpdatedAt)
	return err
}

func (r *PaymentIntentRepo) BindCheckoutIDs(ctx context.Context, id uuid.UUID, checkoutID, merchantID string) error {
	if r.pool == nil {
		return errors.New("database offline")
	}
	_, err := r.pool.Exec(ctx, `
		UPDATE payment_intents SET checkout_request_id=$2, merchant_request_id=$3, updated_at=$4
		WHERE id=$1 AND status='pending'`, id, checkoutID, merchantID, time.Now())
	return err
}

func (r *PaymentIntentRepo) FindByCheckoutRequestID(ctx context.Context, checkoutID string) (*PaymentIntent, error) {
	if r.pool == nil {
		return nil, errors.New("database offline")
	}
	var p PaymentIntent
	err := r.pool.QueryRow(ctx, `
		SELECT id,user_id,loan_id,amount,phone_number,COALESCE(checkout_request_id,''),COALESCE(merchant_request_id,''),
			status,created_at,updated_at,completed_at
		FROM payment_intents WHERE checkout_request_id=$1`, checkoutID).
		Scan(&p.ID, &p.UserID, &p.LoanID, &p.Amount, &p.PhoneNumber, &p.CheckoutRequestID, &p.MerchantRequestID,
			&p.Status, &p.CreatedAt, &p.UpdatedAt, &p.CompletedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, errors.New("payment intent not found")
	}
	return &p, err
}

// CompleteIfPending atomically marks intent completed. Returns false if already completed (idempotent).
func (r *PaymentIntentRepo) CompleteIfPending(ctx context.Context, id uuid.UUID, receipt string) (bool, error) {
	if r.pool == nil {
		return false, errors.New("database offline")
	}
	now := time.Now()
	tag, err := r.pool.Exec(ctx, `
		UPDATE payment_intents SET status='completed', updated_at=$2, completed_at=$2
		WHERE id=$1 AND status='pending'`, id, now)
	if err != nil {
		return false, err
	}
	_ = receipt // reserved for future column; status transition is the idempotency key
	return tag.RowsAffected() > 0, nil
}

func (r *PaymentIntentRepo) Fail(ctx context.Context, id uuid.UUID) error {
	if r.pool == nil {
		return nil
	}
	_, err := r.pool.Exec(ctx, `UPDATE payment_intents SET status='failed', updated_at=$2 WHERE id=$1 AND status='pending'`, id, time.Now())
	return err
}
