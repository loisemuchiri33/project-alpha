# Zeni → Tala-Class Standards Roadmap

**Goal:** Bring Zeni to operational and control standards comparable to mature digital lenders (Tala-class), without claiming feature parity on ML underwriting scale.

## What was fixed in this upgrade pack

### 1. Disbursement integrity (Critical)
- **Before:** Admin "Disburse" could mark loan `active` as soon as B2C was *initiated*.
- **After:** B2C initiation moves loan to `disbursement_pending`. Loan becomes `active` only after confirmed B2C success (ResultURL path / `MarkDisbursed`).
- Dual-control (maker-checker): amounts **≥ KES 20,000** cannot be disbursed by the same admin who approved.

### 2. M-Pesa B2C hardening
- Certificate / PEM / RSA errors no longer swallowed.
- HTTP and Safaricom `ResponseCode` failures return clear errors.
- Phone and minimum amount validation on disbursement.

### 3. Already present (confirmed in current tree)
- Approve ≠ disburse (status `approved` only).
- Apply enforces phone verified + KYC + credit limit.
- STK repayment bound to payment intents + ownership + outstanding cap.
- Admin RBAC, audit log, staff APIs, JWT fails closed in release mode.

---

## Remaining work to reach Tala-class operations

### P0 — Before real money
| # | Item | Why |
|---|------|-----|
| 1 | Wire **B2C ResultURL handler** → call `engine.MarkDisbursed` / `MarkDisbursementFailed` with ConversationID matching | Ledger must follow cash, not initiation |
| 2 | Create **disbursement payment_intent** rows for B2C (like STK) | Full audit trail & reconciliation |
| 3 | Idempotent callback processing | Safaricom can retry |
| 4 | External **pen-test** after P0 | CBK / investor expectation |
| 5 | Production secrets, TLS, WAF, encrypted backups | Ops baseline |

### P1 — Production readiness
| # | Item |
|---|------|
| 6 | Phone verify gate before login token issuance |
| 7 | Full KYC document pipeline + malware scan on MinIO/S3 |
| 8 | Refresh token rotation store + revoke on password change |
| 9 | Redis cluster rate limits (not in-memory only) |
| 10 | Field-level AES encryption fully wired via `ENCRYPTION_KEY` |
| 11 | Multi-AZ RDS + Redis HA when on AWS |
| 12 | CloudWatch/Prometheus alerts on 5xx, B2C fail rate, disbursement lag |

### P2 — Competitive depth (true Tala parity is multi-year)
| # | Item |
|---|------|
| 13 | Alternative-data risk model (device, repayment history, behavioural features) |
| 14 | Automated limit increases after successful cycles |
| 15 | Collections workflow + respectful outreach rules |
| 16 | Multi-market config (currency, rails, regulators) |
| 17 | Dedicated platform team, chaos tests, formal SLOs |

---

## Loan status machine (target)

```
pending → approved → disbursement_pending → active → completed
                ↘ rejected
                ↘ disbursement_failed → (retry disburse) → disbursement_pending
```

Never jump `approved` → `active` without payment-rail confirmation.

---

## How to apply these patches

Copy the updated files into your monorepo:

```
backend/internal/loan/engine.go
backend/internal/payment/mpesa.go
backend/internal/handlers/admin_handler.go
```

Then:

```bash
cd backend
go test ./...
# manual: approve loan → disburse → confirm status is disbursement_pending
# complete B2C ResultURL handler before live disbursements
```

---

## Honest positioning vs Tala

| Dimension | After this pack | Tala today |
|-----------|-----------------|------------|
| Ledger vs cash | Aligned design | Proven at scale |
| Maker-checker | Basic dual control ≥20k | Mature dual control + policies |
| Underwriting | Rules + ladder | Deep ML + years of data |
| Ops maturity | Improving | Enterprise |
| Regulatory | CBK-oriented docs | Licensed multi-country |

Zeni can become **operationally comparable** for a Kenya pilot. Matching Tala’s full risk engine and scale is a product + data journey measured in years, not a single code drop.
