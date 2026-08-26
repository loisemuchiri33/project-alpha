# ZENI Full-Stack Security Assessment

**Date:** 2026-08-13  
**Scope:** Monorepo as uploaded (`backend`, `admin`, `zeni/mobile`, `infrastructure`, `docker-compose`, `docs`) plus prior feature pack (`zeni_build` / workers-CEO)  
**Method:** White-box static review of current tree; delta vs `docs/PENTEST_REPORT.md` (2026-07-23) and `docs/SECURITY_FIXES.md`  
**Overall risk (pre-production):** **High** — prior Critical RBAC/JWT defaults are largely fixed; remaining issues block safe live lending (disbursement without payment rail, missing credit limits, incomplete payments/KYC, unfinished CEO/workers API).

---

## Executive summary

| Severity | Count | Theme |
|----------|------:|-------|
| Critical | 1 | Approve → `active` + `disbursed_at` without M-Pesa B2C / funds movement |
| High     | 5 | No loan-limit enforcement on apply; workers API missing while UI calls it; refresh≈access JWT; rate-limit window slide; callback secret via query string |
| Medium   | 8 | No phone-verify gate; KYC stub; fraud rules underfed; AES helper unused; admin demo mode; memory OTP/rate-limit; B2C nil-cert panic risk; docs overclaim |
| Low      | 5 | Admin tokens in memory only; compose defaults; GenerateKey/Encrypt length mismatch; StaffRequired unused; feature-pack vs main drift |

**Bottom line for CBK / pilot:** Do not disburse real money until C1 and H1–H3 are closed and payment intents are ledger-bound. Prior C1 (missing AdminRequired) and default JWT forgery are **fixed in this tree** when `GIN_MODE=release` and a strong `JWT_SECRET` are set.

---

## Delta vs 2026-07-23 pentest

| Prior ID | Status in this tree | Notes |
|----------|---------------------|--------|
| C1 Admin routes no RBAC | **Fixed** | `AdminRequired()` on `/api/v1/admin/*` |
| C2 Self-approve / no gate | **Partially fixed** | Role gate OK; Approve still marks disbursed without payment |
| C3 Default JWT secret | **Fixed (release)** | `ValidateJWT()` fails closed; weak defaults blocked |
| H1 Open M-Pesa callback | **Mitigated** | Secret + envelope required in release; still no ledger bind |
| H2 OTP in logs | **Fixed** | Phone masked; code not logged |
| H3 STK no ownership | **Fixed** | Owner + active + amount ≤ outstanding |
| H4 Error leakage STK | **Fixed** | Generic client message |
| H5 Hardcoded infra secrets | **Improved** | Compose binds `127.0.0.1`; `.env.example` placeholders; k8s `CHANGE_ME` |
| M1 Login w/o phone verify | **Open** | |
| M2 JWT role hardcoded `user` | **Fixed** | `roleOrDefault(user)` from DB user |
| M3 KYC stub | **Open** | |
| M4 Weak request ID | **Fixed** | `crypto/rand` |
| M5 Rate limit gaps | **Partially open** | Auth 20/min added; in-memory + sliding bug remain |
| M6 Fraud blind | **Open** | Apply event omits phone/device/hour |
| M7 Mobile demo approve | **Improved** | Login no longer silent demo-on-fail; demo store still present |
| M8 Hardcoded login password | **Improved** | Controllers empty / phone-only prefill on admin |

---

## Attack surface (current)

| Surface | Routes / assets | Auth |
|---------|-----------------|------|
| Public | `/health`, `/ready`, `/api/v1/auth/*` | Rate limit only |
| Public payment | `POST /api/v1/payments/callback` | `MPESA_CALLBACK_SECRET` (required in release) |
| Borrower | loans, STK, KYC, profile, change-password | Bearer JWT |
| Admin | dashboard, loans list, approve, reject | JWT + `admin`/`superadmin` |
| Admin UI workers | `GET/POST /admin/workers` (client) | **No matching backend routes** |
| Infra | PG/Redis/MinIO on localhost binds; k8s secrets placeholders | Ops-dependent |

---

## Critical

### C1. Loan approval marks funds disbursed without payment rail

**Asset:** `backend/internal/loan/engine.go` → `Approve`  
**Evidence:**

```go
loan.Status = "active"
loan.DisbursedAt = &now
// no call to payment.MpesaService.DisburseFunds
```

**Impact:** Underwriter click = ledger says money left the company. No B2C, no checkout id, no failure path. Regulatory and financial integrity failure for a digital credit provider.

**Remediation:**

1. Approve → status `approved` (not `active`).  
2. Async disbursement worker calls B2C; on success → `active` + `disbursed_at` + transaction row.  
3. On B2C failure → `disbursement_failed`, alert, no borrower “money received” UX.  
4. Maker-checker for amounts above a threshold.

---

## High

### H1. Loan apply does not enforce credit / product limit

**Asset:** `loan/engine.go` `Apply`  
`CalculateLimit(creditScore)` exists but is never called. Only checks: amount ≥ 500, no active loan, tenor 30 days.

**Impact:** Any verified (or unverified) user can submit arbitrarily large pending loans; underwriter queue becomes the only control. Combined with single-approver flow = concentration risk.

**Remediation:** Load user score/limit; reject if `amount > limit`; cap absolute max; require `kyc_status == approved` before apply (product decision).

### H2. Admin Workers / CEO APIs missing while UI calls them

**Asset:** `admin/zeni_admin/lib/workers_page.dart` → `GET/POST /admin/workers`  
**Backend router:** no workers routes, no `SuperAdminRequired`, no staff create/deactivate, no activity audit.

**Impact:**

- UI silently falls back to fake CEO row on error → operators believe HR controls exist.  
- Feature pack (`zeni_build`) is not merged; installing only UI creates a false control narrative.  
- If pack is merged later without review, prior pack issues return (auto phone-verify, weak passwords, JWT in install docs).

**Remediation:** Either remove Workers nav until backend ships, or merge hardened workers API with SuperAdmin gate + audit + unique email.

### H3. Access and refresh tokens are interchangeable JWTs

**Asset:** `auth/jwt.go`  
Same claims shape; `VerifyToken` does not require `token_use` / `typ`. Refresh path accepts any valid signature.

**Impact:** Stolen short-lived access token can be refreshed into a new pair (within access TTL). No server-side refresh family, no revoke on logout/password change. Refresh TTL default 14 days.

**Remediation:**

- Distinct claim `typ: access|refresh`.  
- Persist refresh `jti` in Redis; rotate and invalidate old on use.  
- Invalidate all refresh on password change / deactivate.  
- Logout endpoint that tears down refresh store.

### H4. In-memory rate limiter never cools under sustained traffic

**Asset:** `middleware/ratelimit.go`  
On each request inside window, `lastSeen = now`, so `time.Since(lastSeen) > window` never becomes true while the client keeps sending. Effective limit is “first N then permanent 429 until idle for full window,” and multi-replica pods don’t share state.

**Impact:** Uneven DoS of legit users behind NAT; weak brute-force control; useless in k8s horizontal scale.

**Remediation:** Fixed window or token bucket with Redis; separate tighter limits for login/OTP (e.g. 5/15min/phone + IP).

### H5. M-Pesa callback secret accepted via query string

**Asset:** `payment_handler.go` `~~removed~~ header X-Callback-Secret only (fixed 2026-08-13)`  
**Impact:** Secret lands in access logs, reverse-proxy logs, APM, Referer leaks. Shared-secret-in-URL is a known anti-pattern.

**Remediation:** Header-only (`X-Callback-Secret` or mTLS / IP allowlist for Daraja). Never log full callback URL. Still required: bind `CheckoutRequestID` → payment intent before any ledger credit (not implemented; callback is accept-only today — good until posting lands).

---

## Medium

### M1. Login without phone verification

Tokens issued regardless of `IsPhoneVerified`. Registration leaves verify false. Password-only account after SIM-related phone reuse is weaker than claimed OTP design.

### M2. KYC is a non-persistent stub

`Submit` logs and returns pending; `Status` always `not_submitted`. Schema has `kyc_documents` but handler never writes. No virus scan, no IDV, no private object ACL enforcement in app code.

### M3. Fraud detector is largely decorative on apply

Apply event sets only `UserID`, `EventType`, `Amount`, `IPAddress`. Rules key on empty `PhoneNumber` / `DeviceID`; `HourOfDay` defaults 0; `review` action does not block (only `reject`/`critical`).

### M4. Field encryption helper unused

`pkg/crypto/encryption.go` AES-256-GCM exists; PII paths store plaintext email/phone/name. `GenerateKey()` returns base64 (≈44 chars) while `Encrypt` requires `len(key)==32` — footgun if adopted naively.

### M5. Admin demo mode grants UI approve capability

`canApprove => role == admin|superadmin || demoMode`. Server still enforces RBAC (good). Risk is process/training and accidental demo build against prod API with a real token mixed in.

### M6. OTP store falls back to process memory

If Redis is down, OTP is in-process map (no TTL sweeper beyond read path, lost on restart, not shared). Prefer fail-closed for OTP in release without Redis.

### M7. B2C `DisburseFunds` ignores PEM/parse errors

```go
block, _ := pem.Decode(certPEM)
cert, _ := x509.ParseCertificate(block.Bytes) // panic if block == nil
```

Will panic or mis-encrypt when cert misconfigured — availability + dangerous silent wrong credential if errors swallowed later.

### M8. Control documentation overstates reality

`docs/SECURITY.md` claims audit log for privileged actions, AES for field secrets, mature fraud — approve/reject log via logger only; no `audit_logs` writes in handlers; KYC/payments incomplete. Investor/CBK risk if docs presented as implemented controls.

---

## Low / informational

- Admin Flutter session holds JWT in Riverpod memory only (no `flutter_secure_storage`) — XSS = session theft; harden CSP on any web host.  
- Compose still uses well-known password *values* for local stack (bound to loopback — OK for laptop, not for shared cloud VM).  
- `StaffRequired` defined, never routed; agents cannot use admin API (stricter than UI “agent” language). Align product vs code.  
- Nginx/k8s look like templates; confirm TLS, `proxy_set_header X-Forwarded-For`, and Gin `TrustedProxies` before relying on `ClientIP` for rate limits.  
- Feature pack vs main: email login, superadmin middleware, activity feed not in main backend.

---

## What’s solid (keep)

| Control | Location |
|---------|----------|
| Argon2id + constant-time verify | `auth/service.go` |
| JWT HMAC alg pin | `auth/jwt.go` |
| Admin RBAC middleware wired | `router.go` + `AdminRequired` |
| JWT role from user record | `jwt.go` `roleOrDefault` |
| Release fail-closed JWT secret | `config.ValidateJWT` |
| Loan GET ownership | `loan_handler.go` |
| STK owner + outstanding cap | `payment_handler.go` |
| Callback secret fail-closed in release | `payment_handler.go` |
| OTP not logged; attempt cap 5; 5m TTL | `auth/service.go` |
| Security headers + CORS allowlist | `middleware/security.go` |
| 30-day tenor forced server-side | `loan/engine.go` |
| Compose ports on 127.0.0.1 | `docker-compose.yml` |
| Mobile tokens in secure storage | login flow |
| Register always `role=user` | `auth.Register` |

---

## Priority roadmap

### Before any real disbursement

1. Split approve vs disburse; B2C + transaction ledger + idempotency.  
2. Enforce loan limits + KYC gate on apply.  
3. Payment intent table; callback verifies amount/phone/checkout id then posts once.  
4. Refresh token store + type claim + revoke on password change.  
5. Production secrets only via vault/K8s; never from feature-pack install docs.

### Before staff pilot

6. Merge or remove Workers UI; SuperAdmin API + audit_logs rows for approve/reject/create staff.  
7. Phone verify required before tokens (or step-up for first loan).  
8. Redis-backed rate limits; fail closed OTP without Redis in release.  
9. Strip demo mode from release admin/mobile flavors.  
10. Fix B2C cert error handling.

### Before CBK narrative / external audit

11. Real KYC pipeline + private bucket + retention policy.  
12. Wire fraud event fields; act on `review`.  
13. Align `SECURITY.md` with implemented controls only.  
14. External pentest + fix verification against live staging with Postgres/Redis/M-Pesa sandbox.

---

## Authz matrix (expected after fixes)

| Actor | Apply loan | Own STK | Other user loan | Admin dashboard | Approve | Create worker |
|-------|:----------:|:-------:|:---------------:|:---------------:|:-------:|:-------------:|
| Anon | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| user | ✓ (limit) | ✓ own | ✗ | ✗ | ✗ | ✗ |
| agent | ✗ | ✗ | read queue only | read | ✗ | ✗ |
| admin | ✗ | ✗ | ✓ | ✓ | ✓ | ✗ |
| superadmin | ✗ | ✗ | ✓ | ✓ | ✓ | ✓ |

*Today: agent has no admin API access; workers APIs absent; approve does not pay out.*

---

## Out of scope / not fully exercised

- Live dynamic API tests against running stack with Postgres  
- M-Pesa sandbox end-to-end  
- Mobile binary reverse engineering / certificate pinning  
- K8s cluster RBAC and network policies in a real cluster  
- Dependency CVE scan (`go.mod` / pubspec) — recommend `govulncheck` + `trivy` in CI  

---

*White-box application security review. Not a substitute for external red-team or CBK ICT audit against production infrastructure.*
