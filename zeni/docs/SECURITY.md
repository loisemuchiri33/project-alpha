# ZENI Security Controls

Target: CBK-aligned digital credit provider posture (Kenya).

## Authentication & Identity
- Argon2id password hashing (memory-hard)
- OTP one-time codes (Redis TTL, single use)
- JWT access + refresh (HS256, rotatable secret)
- Secure storage on mobile (flutter_secure_storage)

## Transport & API
- TLS 1.3 termination at Nginx/edge
- Security headers (HSTS, CSP, X-Frame-Options, nosniff)
- CORS allowlist
- Rate limiting (global + auth endpoints)
- Request IDs for correlation

## Data protection
- AES-256-GCM for field-level secrets
- Separate encryption key from JWT secret
- MinIO object storage for KYC docs (private buckets)
- PII minimization in logs

## Fraud & credit risk
- Multi-rule risk scoring (velocity, amount, device, geo, hour)
- Actions: allow | review | reject
- Loan ladder limits (KES 5k → 35k)

## Access control
- Role-based admin routes
- Audit log table for privileged actions
- Principle of least privilege for DB roles

## Operational
- Secrets via env / K8s secrets (never commit)
- Non-root containers
- Health probes
- Prometheus metrics scrape target
- CI: go test / go vet

## Incident response (minimum)
1. Revoke JWT secret / rotate
2. Force logout via refresh invalidation
3. Freeze disbursements
4. Review audit + payment logs
5. Notify compliance office

## Checklist before production
- [ ] Strong unique secrets (≥32 bytes)
- [ ] TLS certs + HSTS
- [ ] M-Pesa production credentials
- [ ] DB backups encrypted
- [ ] WAF / DDoS fronting
- [ ] Pen-test sign-off
