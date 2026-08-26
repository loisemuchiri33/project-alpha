# Zeni Clean Package (Tala-class control upgrades applied)

This is a **clean full Zeni monorepo** with build artifacts removed and the following upgrades already integrated:

## Integrated upgrades
1. **Loan engine** (`backend/internal/loan/engine.go`)
   - `MarkDisbursementPending` — B2C initiate does not mark loan active
2. **Admin disburse** (`backend/internal/handlers/admin_handler.go`)
   - Dual-control: amounts ≥ KES 20,000 need a different admin than the approver
   - Status → `disbursement_pending` until B2C success is confirmed
3. **M-Pesa B2C** (`backend/internal/payment/mpesa.go`)
   - Proper certificate/error handling (no silent failures)
4. **Roadmap** (`docs/TALA_PARITY_ROADMAP.md`)
   - Remaining P0/P1 work toward production / Tala-class ops

## Still required before live money
- Wire B2C ResultURL → `MarkDisbursed` / `MarkDisbursementFailed`
- Complete KYC pipeline
- External pen-test
- Production secrets, TLS, hosting (AWS recommended for scale)

## Quick start
```bash
docker compose up -d
cd backend && cp .env.example .env   # set strong secrets
go run ./cmd/api/
```

All branding and module paths remain **Zeni** (`github.com/zeni-lending/backend`).
