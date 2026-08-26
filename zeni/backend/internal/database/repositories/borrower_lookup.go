package repositories

import (
	"context"

	"github.com/google/uuid"
	"github.com/zeni-lending/backend/internal/loan"
)

// GetBorrower adapts UserRepo to loan.UserLookup for apply-time policy gates.
func (r *UserRepo) GetBorrower(ctx context.Context, userID uuid.UUID) (*loan.BorrowerProfile, error) {
	u, err := r.FindByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	return &loan.BorrowerProfile{
		IsActive:        u.IsActive,
		IsPhoneVerified: u.IsPhoneVerified,
		KYCStatus:       u.KYCStatus,
		CreditScore:     u.CreditScore,
		LoanLimit:       u.LoanLimit,
	}, nil
}
