# ZENI Architecture

```
[Flutter Mobile] ──HTTPS──▶ [Nginx] ──▶ [Go API :8080]
                                │              │
                                │              ├── PostgreSQL
                                │              ├── Redis (OTP, rate, fraud)
[Admin Web] ────────────────────┘              └── MinIO (KYC)
                                               │
                                          [Worker]
                                    (loan processor / late fees)
```

## Domains
- **auth** — register/login/OTP/JWT
- **loan** — apply, approve, repay schedule, limits
- **payment** — M-Pesa STK + B2C + callbacks
- **fraud** — rule engine scoring
- **kyc** — document capture + review
- **admin** — ops dashboard

## Loan ladder (KES)
5,000 → 10,000 → 15,000 → 20,000 → 25,000 → 30,000 → 35,000

Increases based on on-time repayment history and credit score tiers.
