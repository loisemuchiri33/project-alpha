package workers

import (
	"context"
	"time"

	"github.com/zeni-lending/backend/internal/loan"
	"github.com/zeni-lending/backend/pkg/logger"
)

type OverdueFinder interface {
	FindOverdueLoans(ctx context.Context) ([]*loan.Loan, error)
	Update(ctx context.Context, l *loan.Loan) error
}

type LoanProcessor struct {
	logger     *logger.Logger
	loanEngine *loan.Engine
	loanRepo   OverdueFinder
}

func NewLoanProcessor(log *logger.Logger, engine *loan.Engine, repo OverdueFinder) *LoanProcessor {
	return &LoanProcessor{logger: log, loanEngine: engine, loanRepo: repo}
}

func (p *LoanProcessor) Start(ctx context.Context) {
	p.logger.Info("loan processor started")
	go p.processLateFees(ctx)
}

func (p *LoanProcessor) processLateFees(ctx context.Context) {
	ticker := time.NewTicker(time.Hour)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			loans, err := p.loanRepo.FindOverdueLoans(ctx)
			if err != nil {
				p.logger.Error("overdue fetch failed", "error", err)
				continue
			}
			for _, l := range loans {
				fee := p.loanEngine.CalculateLateFee(l)
				if fee > 0 && fee != l.LateFee {
					l.LateFee = fee
					if err := p.loanRepo.Update(ctx, l); err != nil {
						p.logger.Error("late fee update failed", "loan_id", l.ID, "error", err)
					} else {
						p.logger.Info("late fee applied", "loan_id", l.ID, "fee", fee)
					}
				}
			}
		}
	}
}
