# Security hardening applied (2026-08-13)

## Critical / High
- Wired `AdminRequired()` on all `/api/v1/admin/*` routes
- JWT `role` taken from DB user record (not client-supplied)
- Production (`GIN_MODE=release`) refuses weak/missing `JWT_SECRET`
- M-Pesa callback: Safaricom envelope checks; `MPESA_CALLBACK_SECRET` required in release
- Callback secret accepted via **`X-Callback-Secret` header only** (no query-string fallback)
- STK push bound to payment intents + loan ownership + amount ≤ outstanding
- OTP codes not written to logs (phone masked)
- Approve / reject / disburse track staff id + audit reasons
- Staff CRUD + activity log APIs (CEO gates where required)
- Migration `003_staff_and_activity` (audit_logs, payment_intents, staff indexes)

## Ops admin (Flutter web)
- JWT login (phone **or** email + password); empty defaults (no hardcoded CEO password)
- Portfolio, underwriting queue, approve/reject/**disburse**, workers, activity, health
- Demo mode remains offline-only

## Mobile
- API base via `--dart-define`; tokens via secure storage patterns
- No API secrets embedded in client

## Infra
- docker-compose binds Postgres/Redis/MinIO to `127.0.0.1` only
- `.env.example` and k8s `secrets.yaml` are placeholders only
- `scripts/create_ceo.sh` requires `CEO_PHONE` / `CEO_PASSWORD` env vars (no hardcoded password)

## Still recommended before live lending
- Phone verification gate before issuing login tokens
- Full KYC document pipeline + malware scan
- Complete B2C result → ledger posting with dual control for large amounts
- Redis-backed cluster-wide rate limits
- Refresh token rotation store + revoke on password change / deactivate
- Wire `ENCRYPTION_KEY` through `config.go` for field-level crypto at rest
